const std = @import("std");
const djotToken = @import("Token.zig");
const Tokens = djotToken.tokens;
const Opposite = djotToken.opposite;
const Token = @import("../tokenizer/Token.zig").Token(Tokens);
const Range = @import("../tokenizer/Token.zig").Range;
const TokenStack = @import("../tokenizer/TokenStack.zig").TokenStack(Tokens);
const text_reader = @import("../tokenizer/TextReader.zig");
const TextReader = text_reader.TextReader;
const matchInlineToken = @import("InlineToken.zig").MatchInlineToken;
const matchDjotAttribute = @import("Attributes.zig").matchDjotAttribute;
const matchBlockToken = @import("BlockToken.zig").matchBlockToken;
const Attributes = @import("Attributes.zig").Attributes;
const inlineTokens = @import("InlineToken.zig");
const TokenList = @import("../tokenizer/TokenList.zig").TokenList(Tokens);
const LineTokenizer = @import("../tokenizer/LineTokenizer.zig").LineTokenizer;

pub fn BuildInlineDjotTokens(allocator: std.mem.Allocator, doc: []const u8, cparts: std.ArrayList(Range), tokens: *std.ArrayList(Token)) !void {
    var parts = try cparts.clone();
    defer parts.deinit();
    if (parts.items.len == 0) {
        try parts.append(Range{ .start = 0, .end = doc.len });
    }
    var tokenStack = TokenStack.init(allocator);
    defer tokenStack.deinit();
    const leftDocumentPosition = parts.items[0].start;
    const rightDocumentPosition = parts.items[parts.items.len - 1].end;
    try tokenStack.openLevelAt(Token.init(Tokens.ParagraphBlock, leftDocumentPosition, leftDocumentPosition, null));

    var reader = TextReader.init(doc);
    var state = parts.items[0].start;
    try tokenStack.lastLevel().?.fillUntil(parts.items[0].start, Tokens.Ignore);
    for (parts.items) |part| {
        reader = TextReader.init(doc);
        state = part.start;
        try tokenStack.lastLevel().?.fillUntil(parts.items[0].start, Tokens.Ignore);
        inlineParsingLoop: while (!reader.isEmpty(state)) {
            const openInline = tokenStack.lastLevel().?.firstOrDefault();
            const openInlineType = openInline.tokenType;
            const lastInline = tokenStack.lastLevel().?.lastOrDefault();

            if (openInlineType == Tokens.VerbatimInline) {
                const next = try matchInlineToken(reader, state, Opposite(Tokens.VerbatimInline)) orelse {
                    state += 1;
                    continue;
                };
                const openToken = reader.select(openInline.start, openInline.end);
                const closeToken = reader.select(state, next);
                if (!std.mem.eql(u8, std.mem.trimLeft(u8, openToken, "$"), closeToken)) {
                    state = next;
                    continue;
                }
                try tokenStack.closeLevelAt(Token.init(Opposite(Tokens.VerbatimInline), state, next, null));
                state = next;
                continue;
            }
            var attributes = Attributes.init();
            if (try matchDjotAttribute(allocator, reader, state, &attributes)) |next| {
                try tokenStack.lastLevel().?.push(Token.init(Tokens.Attribute, state, next, attributes));
                state = next;
                continue;
            }
            if (!inlineTokens.InlineTokenStartSymbol.Has(reader.doc[state])) {
                state += 1;
                continue;
            }
            // EscapedSymbolInline / SmartSymbolInline is non-paired tokens - so we should treat it separately
            for ([_]Tokens{ Tokens.EscapedSymbolInline, Tokens.SmartSymbolInline }) |tokenType| {
                if (try matchInlineToken(reader, state, tokenType)) |next| {
                    try tokenStack.lastLevel().?.push(Token.init(tokenType, state, next, null));
                    state = next;
                    continue :inlineParsingLoop;
                }
            }
            for ([_]Tokens{
                Tokens.RawFormatInline,
                Tokens.VerbatimInline,
                Tokens.ImageSpanInline,
                Tokens.LinkUrlInline,
                Tokens.LinkReferenceInline,
                Tokens.AutolinkInline,
                Tokens.EmphasisInline,
                Tokens.StrongInline,
                Tokens.HighlightedInline,
                Tokens.SubscriptInline,
                Tokens.SuperscriptInline,
                Tokens.InsertInline,
                Tokens.DeleteInline,
                Tokens.FootnoteReferenceInline,
                Tokens.SpanInline,
                Tokens.SymbolsInline,
                Tokens.PipeTableSeparator,
            }) |tokenType| {
                var next = try matchInlineToken(reader, state, Opposite(tokenType));
                const forbidClose = ((tokenType == Tokens.EmphasisInline and lastInline.tokenType == Tokens.EmphasisInline) or (tokenType == Tokens.StrongInline and lastInline.tokenType == Tokens.StrongInline)) and lastInline.end == state;
                if (!forbidClose and next != null and try tokenStack.popForgetUntil(tokenType)) {
                    try tokenStack.closeLevelAt(Token.init(Opposite(tokenType), state, next.?, null));
                    state = next.?;
                    continue :inlineParsingLoop;
                }
                if (tokenType == Tokens.RawFormatInline and lastInline.tokenType != Opposite(Tokens.VerbatimInline)) {
                    continue;
                }
                if ((tokenType == Tokens.LinkReferenceInline or tokenType == Tokens.LinkUrlInline) and lastInline.tokenType != Opposite(Tokens.SpanInline) and lastInline.tokenType != Opposite(Tokens.ImageSpanInline)) {
                    continue;
                }
                next = try matchInlineToken(reader, state, tokenType);
                if (next != null) {
                    attributes = Attributes.init();
                    const token = reader.doc[state..next.?];
                    if (tokenType == Tokens.VerbatimInline) {
                        if (std.mem.startsWith(u8, token, "$$")) {
                            try attributes.set(allocator, djotToken.DisplayMathKey, "");
                        } else if (std.mem.startsWith(u8, token, "$")) {
                            try attributes.set(allocator, djotToken.InlineMathKey, "");
                        }
                    }
                    var tok = Token.init(tokenType, state, next.?, null);
                    tok.attributes = attributes;
                    try tokenStack.openLevelAt(tok);
                    state = next.?;
                    continue :inlineParsingLoop;
                }
            }
            state += 1;
        }
    }
    if (tokenStack.lastLevel().?.firstOrDefault().tokenType == Tokens.VerbatimInline) {
        try tokenStack.closeLevelAt(Token.init(Opposite(Tokens.VerbatimInline), rightDocumentPosition, rightDocumentPosition, null));
    }
    _ = try tokenStack.popForgetUntil(Tokens.ParagraphBlock);
    try tokenStack.closeLevelAt(Token.init(Tokens.ParagraphBlock, rightDocumentPosition, rightDocumentPosition, null));
    for (tokenStack.lastLevel().?.*.items.items, 0..) |token, i| {
        if (i == 0) {
            continue;
        }
        try tokens.append(token);
    }
    _ = tokens.pop();
}

pub const BuildDjotTokens = struct {
    allocator: std.mem.Allocator,

    doc: []const u8,

    lineTokenizer: LineTokenizer,
    inlineParts: std.ArrayList(Range),
    blockLineOffset: std.ArrayList(usize),
    blockTokenOffset: std.ArrayList(usize),

    blockTokens: std.ArrayList(Token),
    finalTokens: std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator, doc: []const u8) !BuildDjotTokens {
        var self = BuildDjotTokens{};
        self.allocator = allocator;

        self.doc = doc;

        self.lineTokenizer = LineTokenizer.init(doc);
        self.inlineParts = std.ArrayList(Range).init(allocator);
        self.blockLineOffset = std.ArrayList(usize).init(allocator);
        self.blockTokenOffset = std.ArrayList(usize).init(allocator);

        self.blockTokens = std.ArrayList(Token).init(allocator);
        self.finalTokens = std.ArrayList(Token).init(allocator);
        self.blockTokens.append(Token.init(Tokens.DocumentBlock, 0, 0, null));
        self.finalTokens.append(Token.init(Tokens.DocumentBlock, 0, 0, null));
        return self;
    }
    fn popMetadata(self: *BuildDjotTokens) void {
        self.blockLineOffset.pop();
        self.blockTokenOffset.pop();
        self.blockTokens.pop();
    }
    fn openBlockLevel(self: *BuildDjotTokens, token: Token) !void {
        try self.finalTokens.append(token);
        try self.blockTokenOffset.append(self.blockTokens.items.len - 1);
        try self.blockTokens.append(token);
    }

    fn closeBlockLevelsUntil(self: *BuildDjotTokens, start: usize, end: usize, level: usize) !void {
        if (self.inlineParts.items.len != 0 and self.blockTokens.getLast().tokenType == Tokens.CodeBlock) {
            for (self.inlineParts.items) |part| {
                try self.finalTokens.append(Token.init(Tokens.None, part.start, part.end));
            }
            self.inlineParts.clearAndFree();
        } else if (self.inlineParts.items.len != 0) {
            var inlineToks = std.ArrayList(Token).init(self.allocator);
            defer inlineToks.deinit();
            try BuildInlineDjotTokens(self.allocator, self.inlineParts, &inlineToks);
            try self.finalTokens.appendSlice(inlineToks.items);
            self.inlineParts.clearAndFree();
        }
        var i = self.blockTokens.items.len - 1;
        while (i > level) : (i -= 1) {
            try self.finalTokens.append(Token.init(Opposite(self.blockTokens.items[i].tokenType), start, end));
            const delta = self.finalTokens.items.len - 1 - self.blockTokenOffset.items[i];
            self.finalTokens.items[self.blockTokenOffset.items[i]].jumpToPair = delta;
            self.finalTokens.items[self.finalTokens.items.len - 1].jumpToPair = -delta;
            self.popMetadata();
        }
    }

    pub fn build(self: *BuildDjotTokens) !?TokenList {
        while (true) {
            const line = self.lineTokenizer.scan() orelse break;
            const reader = TextReader.init(self.doc[0..line.end]);
            const state = line.start;
            var lastBlock = self.blockTokens.getLast();
            var lastBlockType = lastBlock.tokenType;

            if (inAny(Tokens, lastBlockType, []Tokens{ Tokens.DocumentBlock, Tokens.QuoteBlock, Tokens.ListItemBlock, Tokens.DivBlock })) {
                const next = reader.maskRepeat(state, text_reader.SpaceByteMask, 0) orelse return error.MinCountErr;
                var attributes = Attributes.init();
                if (try matchDjotAttribute(self.allocator, reader, next, &attributes)) |nnext| {
                    if (reader.emptyOrWhiteSpace(nnext)) |nnnext| {
                        self.finalTokens.append(Token.init(Tokens.Attribute, state, nnnext, attributes));
                        continue;
                    }
                }
            }

            var lastDivAt = -1;
            for (self.blockTokens.items, 0..) |blockToken, i| {
                if (blockToken.tokenType == Tokens.DivBlock) {
                    lastDivAt = i;
                }
            }
            var resetBlockAt = 0;
            var potentialReset = false;
            for (self.blockTokens.items, 0..) |blockToken, i| {
                switch (blockToken.tokenType) {
                    .ListItemBlock, .FootnoteDefBlock => {
                        const next = reader.maskRepat(state, text_reader.SpaceByteMask, 0) orelse return error.MinCountErr;
                        if (!reader.emptyOrWhiteSpace(next) and next - line.start <= self.blockLineOffset.items[i]) {
                            potentialReset = true;
                            break;
                        }
                        resetBlockAt = i;
                    },
                    .ReferenceDefBlock => {
                        const next = reader.maskRepat(state, text_reader.SpaceByteMask, 0) orelse return error.MinCountErr;
                        if (next - line.start <= self.blockLineOffset.items[i]) {
                            potentialReset = true;
                            break;
                        }
                        resetBlockAt = i;
                    },
                    .QuoteBlock, .HeadingBlock => {
                        const next = try matchBlockToken(self.allocator, reader, blockToken.tokenType) orelse {
                            potentialReset = true;
                            break;
                        };
                        state = next.state;
                        resetBlockAt = i;
                    },
                    .ParagraphBlock, .HeadingBlock, .PipeTableCaptionBlock => {
                        resetBlockAt = i;
                    },
                }
            }
            if ((lastBlockType != Tokens.CodeBlock or potentialReset) and reader.emptyOrWhiteSpace(state)) {
                self.closeBlockLevelsUntil(state, state, resetBlockAt);
                continue;
            }
            if (lastBlockType == Tokens.ReferenceDefBlock) {
                self.closeBlockLevelsUntil(state, state, resetBlockAt);
            } else if (lastBlockType == Tokens.CodeBlock) {
                const token = try matchBlockToken(self.allocator, reader, state, Tokens.CodeBlock);
                if (token != null and lastBlock.prefixLength(self.doc, '`' <= token.?.token.prefixLength(self.doc, '`'))) {
                    self.closeBlockLevelsUntil(token.?.token.start, token.?.token.end, self.blockTokens.items.len - 2);
                } else {
                    self.inlineParts.append(Range{ .start = state, .end = line.end });
                }
                continue;
            }
            if (lastDivAt != -1) {
                if (try matchBlockToken(reader, state, Tokens.DivBlock)) |token| {
                    if (lastBlock.length() <= token.token.length() and token.token.attributes != null and token.token.attributes.?.size() == 0) {
                        self.closeBlockLevelsUntil(token.token.start, token.token.end, lastDivAt - 1);
                        continue;
                    }
                }
            }

            blockParsingLoop: while (true) {
                lastBlock = self.blockTokens.getLast();
                lastBlockType = lastBlock.tokenType;
                if (try matchBlockToken(reader, state, Tokens.ThematicBreakToken)) |tbt| {
                    try self.finalTokens.append(Token.init(Tokens.ThematicBreakToken, tbt.token.start, tbt.token.end, null));
                    state = tbt.state;
                    continue :blockParsingLoop;
                }
            }
        }
    }
};

fn inAny(comptime T: type, value: T, array: []T) bool {
    for (array) |item| {
        if (item == value) {
            return true;
        }
    }
    return false;
}

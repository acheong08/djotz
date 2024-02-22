const std = @import("std");
const Range = @import("../tokenizer/Token.zig").Range;
const djotToken = @import("Token.zig");
const Tokens = djotToken.tokens;
const Opposite = djotToken.opposite;
const Token = @import("../tokenizer/Token.zig").Token(Tokens);
const TokenStack = @import("../tokenizer/TokenStack.zig").TokenStack(Tokens);
const TextReader = @import("../tokenizer/TextReader.zig").TextReader;
const matchInlineToken = @import("InlineToken.zig").MatchInlineToken;
const matchDjotAttribute = @import("Attributes.zig").matchDjotAttribute;
const Attributes = @import("Attributes.zig").Attributes;
const inlineTokens = @import("InlineToken.zig");

pub fn BuildInlineDjotTokens(allocator: std.mem.Allocator, doc: []const u8, parts: *std.ArrayList(Range), tokens: *std.ArrayList(Token)) !void {
    if (parts.items.len == 0) {
        try parts.append(Range{ .start = 0, .end = doc.len });
    }
    var tokenStack = TokenStack.init(allocator);
    defer tokenStack.deinit();
    const leftDocumentPosition = parts.items[0].start;
    const rightDocumentPosition = parts.items[parts.items.len - 1].end;
    try tokenStack.openLevelAt(Token.init(Tokens.ParagraphBlock, leftDocumentPosition, leftDocumentPosition));

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
                try tokenStack.closeLevelAt(Token.init(Opposite(Tokens.VerbatimInline), state, next));
                state = next;
                continue;
            }
            var attributes = Attributes.init(allocator);
            if (try matchDjotAttribute(reader, state, &attributes)) |next| {
                var tok = Token.init(Tokens.Attribute, state, next);
                tok.attributes = attributes;
                try tokenStack.lastLevel().?.push(tok);
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
                    try tokenStack.lastLevel().?.push(Token.init(tokenType, state, next));
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
                    try tokenStack.closeLevelAt(Token.init(Opposite(tokenType), state, next.?));
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
                    attributes = Attributes.init(allocator);
                    const token = reader.doc[state..next.?];
                    if (tokenType == Tokens.VerbatimInline) {
                        if (std.mem.startsWith(u8, token, "$$")) {
                            try attributes.set(djotToken.DisplayMathKey, "");
                        } else if (std.mem.startsWith(u8, token, "$")) {
                            try attributes.set(djotToken.InlineMathKey, "");
                        }
                    }
                    var tok = Token.init(tokenType, state, next.?);
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
        try tokenStack.closeLevelAt(Token.init(Opposite(Tokens.VerbatimInline), rightDocumentPosition, rightDocumentPosition));
    }
    _ = try tokenStack.popForgetUntil(Tokens.ParagraphBlock);
    try tokenStack.closeLevelAt(Token.init(Tokens.ParagraphBlock, rightDocumentPosition, rightDocumentPosition));
    for (tokenStack.lastLevel().?.*.items.items, 0..) |token, i| {
        if (i == 0) {
            continue;
        }
        try tokens.append(token);
    }
    _ = tokens.pop();
}

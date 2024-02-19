const std = @import("std");
const tokenizer = @import("../tokenizer/TextReader.zig");
const tokens = @import("Token.zig").tokens;
const Token = @import("../tokenizer/Token.zig").Token(tokens);
const blockKeys = @import("Token.zig").blockKeys;
const DjotAttributeClassKey = @import("Attributes.zig").DjotAttributeClassKey;
const Attributes = @import("../tokenizer/Attributes.zig").Attributes;

pub const NotSpaceByteMask = tokenizer.SpaceNewLineByteMask.Negate();
pub const NotBracketByteMask = tokenizer.ByteMask.init("]").Negate();
pub const ThematicBreakByteMask = tokenizer.ByteMask.init(" \t\n*-");
pub const DigitByteMask = tokenizer.ByteMask.init("0123456789");
pub const LowerAlphaByteMask = tokenizer.ByteMask.init("abcdefghijklmnopqrstuvwxyz");
pub const UpperAlphaByteMask = tokenizer.ByteMask.init("ABCDEFGHIJKLMNOPQRSTUVWXYZ");
pub const AttributeTokenMask = tokenizer.Union(&[_]tokenizer.ByteMask{
    DigitByteMask,
    LowerAlphaByteMask,
    UpperAlphaByteMask,
    tokenizer.ByteMask.init("-_:"),
});

const string: type = []const u8;
pub fn matchBlockToken(allocator: std.mem.Allocator, reader: tokenizer.TextReader, initialState: usize, tokenType: tokens) !?struct { token: Token, state: usize } {
    const initState = reader.maskRepeat(initialState, tokenizer.SpaceByteMask, 0) orelse return error.MinCountError;
    var next = initState;
    switch (tokenType) {
        tokens.HeadingBlock => {
            next = reader.byteRepeat(next, '#', 1) orelse return null;
            next = reader.mask(next, tokenizer.SpaceByteMask) orelse return null;
            return .{ .state = next, .token = Token.init(tokenType, initState, next) };
        },
        tokens.QuoteBlock => {
            next = reader.byteRepeat(next, '>', 1) orelse return null;
            next = reader.mask(next, tokenizer.SpaceNewLineByteMask) orelse return null;
            return .{ .state = next, .token = Token.init(tokenType, initState, next) };
        },
        tokens.DivBlock, tokens.CodeBlock => {
            var symbol: u8 = undefined;
            var attributeKey: []const u8 = undefined;
            switch (tokenType) {
                tokens.DivBlock => {
                    symbol = ':';
                    attributeKey = DjotAttributeClassKey;
                },
                tokens.CodeBlock => {
                    symbol = '`';
                    attributeKey = DjotAttributeClassKey;
                },
                else => unreachable,
            }
            next = reader.byteRepeat(next, symbol, 3) orelse return null;
            next = reader.maskRepeat(next, tokenizer.SpaceByteMask, 0) orelse return error.MinCountError;
            if (reader.emptyOrWhiteSpace(next)) |end| {
                return .{ .state = end, .token = Token.init(tokenType, initState, next) };
            }
            const metaStart = next;
            next = reader.maskRepeat(next, NotSpaceByteMask, 1) orelse return error.MinCountError;
            const metaEnd = next;

            next = reader.emptyOrWhiteSpace(next) orelse return null;

            var token = Token.init(tokenType, initState, next);
            token.attributes = Attributes.init(allocator);
            try token.attributes.?.set(attributeKey, reader.select(metaStart, metaEnd));
            return .{ .token = token, .state = next };
        },
        tokens.ReferenceDefBlock, tokens.FootnoteDefBlock => {
            next = reader.maskRepeat(next, ThematicBreakByteMask, 0) orelse return error.MinCountError;
            if (!reader.isEmpty(next)) {
                return null;
            }
            if (std.mem.count(u8, reader.doc[initialState..next], "*") < 3 and std.mem.count(u8, reader.doc[initialState..next], "-") < 3) {
                return null;
            }
            return .{ .state = next, .token = Token.init(tokenType, initState, next) };
        },
        tokens.ListItemBlock => {
            inline for ([_]string{ "- [ ] ", "- [x] ", "- [X] ", "+ ", "* ", "- ", ": " }) |simpleToken| {
                if (reader.token(next, simpleToken)) |simple| {
                    return .{ .state = simple, .token = Token.init(tokenType, initialState, simple) };
                }
            }
            for ([_]tokenizer.ByteMask{ DigitByteMask, LowerAlphaByteMask, UpperAlphaByteMask }) |complexTokenMask| {
                var complexNext = next;
                const parenOpen = reader.token(next, "(");
                if (parenOpen) |open| {
                    complexNext = open;
                }
                complexNext = reader.maskRepeat(complexNext, complexTokenMask, 1) orelse continue;
                if (reader.token(complexNext, ") ")) |ending| {
                    return .{ .state = ending, .token = Token.init(tokenType, initialState, ending) };
                } else if (reader.token(complexNext, ". ")) |ending| {
                    return .{ .state = ending, .token = Token.init(tokenType, initialState, ending) };
                }
            }
            return null;
        },
        tokens.PipeTableBlock => {
            if (next >= reader.doc.len or reader.doc[next] != '|') {
                return null;
            }
            var last = reader.doc.len - 1;
            while (last > next and reader.hasMask(last, tokenizer.SpaceNewLineByteMask)) {
                last -= 1;
            }
            if (reader.doc[last] != '|') {
                return null;
            }
            return .{ .state = initialState, .token = Token.init(tokenType, initialState, initialState) };
        },
        tokens.ParagraphBlock => {
            if (reader.isEmpty(next)) {
                return null;
            }
            return .{ .state = next, .token = Token.init(tokenType, initialState, next) };
        },
        tokens.PipeTableCaptionBlock => {
            next = reader.token(next, "^ ") orelse return null;
            return .{ .state = next, .token = Token.init(tokenType, initialState, next) };
        },
        else => unreachable,
    }
}

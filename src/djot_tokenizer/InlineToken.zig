const std = @import("std");
const ByteMask = @import("../tokenizer/TextReader.zig").ByteMask;
const tokenizer = @import("../tokenizer/TextReader.zig");
const Tokens = @import("Token.zig");
const opposite = Tokens.opposite;
const tokens = Tokens.tokens;

pub const DollarByteMask = ByteMask.init("$");
pub const BacktickByteMask = ByteMask.init("`");
pub const SmartSymbolByteMask = ByteMask.init("\n'\"");
pub const AlphaNumericSymbolByteMask = ByteMask.init("+-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
pub const InlineTokenStartSymbol = ByteMask.init("!\"$'()*+-.:<=>[\\]^_`{|}~").Or(tokenizer.SpaceNewLineByteMask);

const RecordStartSymbol = true;

fn matchInlineToken(reader: tokenizer.TextReader, state: usize, tokenType: tokens) !?usize {
    switch (tokenType) {
        tokens.RawFormatInline => {
            return reader.token(state, "{=");
        },
        opposite(tokens.RawFormatInline) => {
            return reader.token(state, "}");
        },
        tokens.VerbatimInline => {
            const next = reader.maskRepeat(state, DollarByteMask, 1) orelse return error.MinCountError;
            if ((next - state) > 2) {
                return null;
            }
            return reader.maskRepeat(next, BacktickByteMask, 1);
        },
        opposite(tokens.VerbatimInline) => {
            return reader.maskRepeat(state, BacktickByteMask, 1);
        },
        tokens.ImageSpanInline => {
            return reader.token(state, "![");
        },
        tokens.SpanInline => {
            return reader.token(state, "[");
        },
        opposite(tokens.SpanInline), opposite(tokens.ImageSpanInline) => {
            return reader.token(state, "]");
        },
        tokens.LinkUrlInline => {
            return reader.token(state, "(");
        },
        opposite(tokens.LinkUrlInline) => {
            return reader.token(state, ")");
        },
        tokens.LinkReferenceInline => {
            return reader.token(state, "[");
        },
        opposite(tokens.LinkReferenceInline) => {
            return reader.token(state, "]");
        },
        tokens.AutolinkInline => {
            return reader.token(state, "<");
        },
        opposite(tokens.AutolinkInline) => {
            return reader.token(state, ">");
        },
        tokens.EscapedSymbolInline => {
            var next = reader.token(state, "\\") orelse return null;
            if (reader.isEmpty(next)) {
                return null;
            }
            if (reader.maskRepeat(next, tokenizer.SpaceByteMask, 0)) |asciiNext| {
                return asciiNext;
            }
            next = reader.maskRepeat(next, tokenizer.SpaceByteMask, 0) orelse return error.MinCountError;
            return reader.token(next, "\n");
        },
        tokens.EmphasisInline => {
            if (reader.token(state, "{_")) |next| {
                return next;
            }
            const next = reader.token(state, "_");
            if (next != null and !reader.hasMask(next.?, tokenizer.SpaceNewLineByteMask)) {
                return next;
            }
            return null;
        },
        opposite(tokens.EmphasisInline) => {
            if (reader.token(state, "_}")) |next| {
                return next;
            }
            const next = reader.token(state, "_");
            if (next != null and state > 0 and !reader.hasMask(state - 1, tokenizer.SpaceNewLineByteMask)) {
                return next;
            }
            return null;
        },
        tokens.StrongInline => {
            if (reader.token(state, "{*")) |next| {
                return next;
            }
            const next = reader.token(state, "*");
            if (next != null and !reader.hasMask(next.?, tokenizer.SpaceNewLineByteMask)) {
                return next;
            }
            return null;
        },
        opposite(tokens.StrongInline) => {
            if (reader.token(state, "*}")) |next| {
                return next;
            }
            const next = reader.token(state, "*");
            if (next != null and state > 0 and !reader.hasMask(state - 1, tokenizer.SpaceNewLineByteMask)) {
                return next;
            }
            return null;
        },
        tokens.HighlightedInline => {
            return reader.token(state, "{=");
        },
        opposite(tokens.HighlightedInline) => {
            return reader.token(state, "=}");
        },
        tokens.SubscriptInline => {
            if (reader.token(state, "{~")) |next| {
                return next;
            }
            return reader.token(state, "~");
        },
        opposite(tokens.SubscriptInline) => {
            if (reader.token(state, "~}")) |next| {
                return next;
            }
            return reader.token(state, "~");
        },
        tokens.SuperscriptInline => {
            if (reader.token(state, "{^")) |next| {
                return next;
            }
            return reader.token(state, "^");
        },
        opposite(tokens.SuperscriptInline) => {
            if (reader.token(state, "^}")) |next| {
                return next;
            }
            return reader.token(state, "^");
        },
        tokens.InsertInline => {
            return reader.token(state, "{+");
        },
        opposite(tokens.InsertInline) => {
            return reader.token(state, "+}");
        },
        tokens.DeleteInline => {
            return reader.token(state, "{-");
        },
        opposite(tokens.DeleteInline) => {
            return reader.token(state, "-}");
        },
        tokens.FootnoteReferenceInline => {
            return reader.token(state, "[^");
        },
        opposite(tokens.FootnoteReferenceInline) => {
            return reader.token(state, "]");
        },
        tokens.SymbolsInline => {
            const next = reader.token(state, ":") orelse return null;
            const word = reader.maskRepeat(next, AlphaNumericSymbolByteMask, 0);
            if (word != null and reader.hasToken(word.?, ":")) {
                return next;
            }
            return null;
        },
        opposite(tokens.SymbolsInline) => {
            return reader.token(state, ":");
        },
        tokens.PipeTableSeparator => {
            const next = reader.token(state, "|") orelse return null;
            return reader.maskRepeat(next, tokenizer.SpaceByteMask, 0);
        },
        opposite(tokens.PipeTableSeparator) => {
            const s = reader.maskRepeat(state, tokenizer.SpaceByteMask, 0) orelse return error.MinCountError;
            if (reader.token(s, "|")) |next| {
                if (reader.emptyOrWhiteSpace(next)) |end| {
                    return end;
                }
                return s;
            }
            return null;
        },
        tokens.SmartSymbolInline => {
            if (reader.token(state, "{")) |next| {
                return next;
            }
            if (reader.mask(state, SmartSymbolByteMask)) |next| {
                if (reader.hasToken(next, "}")) {
                    return next + 1;
                }
                return next;
            }
            if (reader.token(state, "...")) |next| {
                return next;
            }
            return reader.byteRepeat(state, '-', 2);
        },
        else => unreachable,
    }
}

test "matchInlineToken" {
    const reader = tokenizer.TextReader.init("*hi*");
    try std.testing.expectEqual(1, matchInlineToken(reader, 0, tokens.StrongInline));
}

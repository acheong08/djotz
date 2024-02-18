const std = @import("std");
const ByteMask = @import("../tokenizer/TextReader.zig").ByteMask;
const tokenizer = @import("../tokenizer/TextReader.zig");
const tokens = @import("Token.zig").tokens;
const minCountError = @import("BlockToken.zig").minCountError;

pub const DollarByteMask = ByteMask.init("$");
pub const BacktickByteMask = ByteMask.init("`");
pub const SmartQuoteByteMask = ByteMask.init("\n'\"");
pub const AlphaNumericSymbolByteMask = ByteMask.init("+-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
pub const InlineTokenStartSymbol = ByteMask.init("!\"$'()*+-.:<=>[\\]^_`{|}~").Or(tokenizer.SpaceNewLineByteMask);

const RecordStartSymbol = true;

fn matchInlineToken(reader: tokenizer.TextReader, state: usize, tokenType: tokens) !?usize {
    switch (tokenType) {
        tokens.RawFormatInline => {
            return reader.token(state, [_]u8{ '{', '=' });
        },
        tokens.RawFormatInline ^ 1 => {
            return reader.token(state, [_]u8{'}'});
        },
        tokens.VerbatimInline => {
            const next = reader.maskRepeat(state, DollarByteMask, 1) orelse return minCountError;
            if ((next - state) > 2) {
                return null;
            }
            return reader.maskRepeat(next, BacktickByteMask, 1);
        },
        tokens.VerbatimInline ^ 1 => {
            return reader.maskRepeat(state, BacktickByteMask, 1);
        },
        tokens.ImageSpanInline => {
            return reader.token(state, [_]u8{ '!', '[' });
        },
        tokens.SpanInline => {
            return reader.token(state, [_]u8{'['});
        },
        tokens.SpanInline ^ 1, tokens.ImageSpanInline ^ 1 => {
            return reader.token(state, [_]u8{']'});
        },
        tokens.LinkUrlInline => {
            return reader.token(state, [_]u8{'('});
        },
        tokens.LinkUrlInline ^ 1 => {
            return reader.token(state, [_]u8{')'});
        },
        tokens.LinkReferenceInline => {
            return reader.token(state, [_]u8{'['});
        },
        tokens.LinkReferenceInline ^ 1 => {
            return reader.token(state, [_]u8{']'});
        },
        tokens.AutolinkInline => {
            return reader.token(state, [_]u8{'<'});
        },
        tokens.AutolinkInline ^ 1 => {
            return reader.token(state, [_]u8{'>'});
        },
        tokens.EscapedSymbolInline => {
            const next = reader.token(state, [_]u8{'\\'}) orelse return null;
            if (reader.isEmpty(next)) {
                return null;
            }
            if (reader.maskRepeat(next, tokenizer.SpaceByteMask, 0)) |asciiNext| {
                return asciiNext;
            }
            next = reader.maskRepeat(next, tokenizer.SpaceByteMask, 0) orelse return minCountError;
            return reader.token(next, [_]u8{'\n'});
        },
    }
}

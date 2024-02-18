const std = @import("std");
const ByteMask = @import("../tokenizer/TextReader.zig").ByteMask;
const tokenizer = @import("../tokenizer/TextReader.zig");
const tokens = @import("Token.zig").tokens;
const minCountError = @import("BlockToken.zig").minCountError;

pub const DollarByteMask = ByteMask.init("$");
pub const BacktickByteMask = ByteMask.init("`");
pub const SmartSymbolByteMask = ByteMask.init("\n'\"");
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
        tokens.EmphasisInline => {
            if (reader.token(state, [_]u8{ '{', '_' })) |next| {
                return next;
            }
            const next = reader.token(state, [_]u8{'_'});
            if (next and !reader.hasMask(next, tokenizer.SpaceNewLineByteMask)) {
                return next;
            }
            return null;
        },
        tokens.EmphasisInline ^ 1 => {
            if (reader.token(state, [_]u8{ '_', '}' })) |next| {
                return next;
            }
            const next = reader.token(state, [_]u8{'_'});
            if (next and state > 0 and !reader.hasMask(state - 1, tokenizer.SpaceNewLineByteMask)) {
                return next;
            }
            return null;
        },
        tokens.StrongInline => {
            if (reader.token(state, [_]u8{ '{', '*' })) |next| {
                return next;
            }
            const next = reader.token(state, [_]u8{'*'});
            if (next and !reader.hasMask(next, tokenizer.SpaceNewLineByteMask)) {
                return next;
            }
            return null;
        },
        tokens.StrongInline ^ 1 => {
            if (reader.token(state, [_]u8{ '*', '}' })) |next| {
                return next;
            }
            const next = reader.token(state, [_]u8{'*'});
            if (next and state > 0 and !reader.hasMask(state - 1, tokenizer.SpaceNewLineByteMask)) {
                return next;
            }
            return null;
        },
        tokens.HighlightedInline => {
            return reader.token(state, [_]u8{ '{', '=' });
        },
        tokens.HighlightedInline ^ 1 => {
            return reader.token(state, [_]u8{ '=', '}' });
        },
        tokens.SubscriptInline => {
            if (reader.token(state, [_]u8{ '{', '~' })) |next| {
                return next;
            }
            return reader.token(state, [_]u8{'~'});
        },
        tokens.SubscriptInline ^ 1 => {
            if (reader.token(state, [_]u8{ '~', '}' })) |next| {
                return next;
            }
            return reader.token(state, [_]u8{'~'});
        },
        tokens.SuperscriptInline => {
            if (reader.token(state, [_]u8{ '{', '^' })) |next| {
                return next;
            }
            return reader.token(state, [_]u8{'^'});
        },
        tokens.SuperscriptInline ^ 1 => {
            if (reader.token(state, [_]u8{ '^', '}' })) |next| {
                return next;
            }
            return reader.token(state, [_]u8{'^'});
        },
        tokens.InsertInline => {
            return reader.token(state, [_]u8{ '{', '+' });
        },
        tokens.InsertInline ^ 1 => {
            return reader.token(state, [_]u8{ '+', '}' });
        },
        tokens.DeleteInline => {
            return reader.token(state, [_]u8{ '{', '-' });
        },
        tokens.DeleteInline ^ 1 => {
            return reader.token(state, [_]u8{ '-', '}' });
        },
        tokens.FootnoteReferenceInline => {
            return reader.token(state, [_]u8{ '[', '^' });
        },
        tokens.FootnoteReferenceInline ^ 1 => {
            return reader.token(state, [_]u8{']'});
        },
        tokens.SymbolsInline => {
            const next = reader.token(state, [_]u8{':'}) orelse return null;
            const word = reader.maskRepeat(next, AlphaNumericSymbolByteMask, 0);
            if (word and reader.hasToken(word.?, [_]u8{':'})) {
                return next;
            }
            return null;
        },
        tokens.SymbolsInline ^ 1 => {
            return reader.token(state, [_]u8{':'});
        },
        tokens.PipeTableSeparator => {
            const next = reader.token(state, [_]u8{'|'}) orelse return null;
            return reader.maskRepeat(next, tokenizer.SpaceByteMask, 0);
        },
        tokens.PipeTableSeparator ^ 1 => {
            const s = reader.maskRepeat(state, tokenizer.SpaceByteMask, 0) orelse return minCountError;
            if (reader.token(s, [_]u8{'|'})) |next| {
                if (reader.emptyOrWhiteSpace(next)) {
                    return next;
                }
                return s;
            }
            return null;
        },
        tokens.SmartSymbolInline => {
            if (reader.token(state, [_]u8{'{'})) |next| {
                return next;
            }
            if (reader.token(state, SmartSymbolByteMask)) |next| {
                if (reader.hasToken(next, [_]u8{'}'})) {
                    return next + 1;
                }
                return next;
            }
            if (reader.token(state, [3]u8{ '.', '.', '.' })) |next| {
                return next;
            }
            return reader.byteRepeat(state, '-', 2);
        },
        else => unreachable,
    }
}

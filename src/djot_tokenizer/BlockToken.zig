const tokenizer = @import("../tokenizer/TextReader.zig");

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

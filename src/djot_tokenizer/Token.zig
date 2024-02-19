const std = @import("std");

// pub const DivClassKey = "$DivClassKey";
// pub const CodeLangKey = "$CodeLangKey";
// pub const InlineMathKey = "$InlineMathKey";
// pub const DisplayMathKey = "$DisplayMathKey";
// pub const ReferenceKey = "$ReferenceKey";

pub const blockKeys = enum {
    DivClassKey,
    CodeLangKey,
    InlineMathKey,
    DisplayMathKey,
    ReferenceKey,
};

fn tokenEnum(names: anytype) type {
    var fields: [2 + names.len * 2]std.builtin.Type.EnumField = undefined;
    fields[0] = .{ .name = "None", .value = 0 };
    fields[1] = .{ .name = "Ignore", .value = 1 };
    inline for (names, 0..) |name, i| {
        fields[2 + i * 2] = .{ .name = @tagName(name), .value = 2 * (i + 2) + 1 };
        fields[2 + i * 2 + 1] = .{ .name = @tagName(name) ++ "Close", .value = 2 * (i + 2) };
    }
    return @Type(.{ .Enum = .{
        .tag_type = u64,
        .fields = &fields,
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_exhaustive = true,
    } });
}

pub fn opposite(e: anytype) @TypeOf(e) {
    return @enumFromInt(@intFromEnum(e) ^ 1);
}

pub const tokens = tokenEnum(.{
    .DocumentBlock,
    .HeadingBlock,
    .QuoteBlock,
    .ListItemBlock,
    .CodeBlock,
    .DivBlock,
    .PipeTableBlock,
    .ReferenceDefBlock,
    .FootnoteDefBlock,
    .ParagraphBlock,
    .ThematicBreakToken,
    .PipeTableCaptionBlock,
    .Attribute,
    .Padding,
    .RawFormatInline,
    .VerbatimInline,
    .ImageSpanInline,
    .LinkUrlInline,
    .LinkReferenceInline,
    .AutolinkInline,
    .EscapedSymbolInline,
    .EmphasisInline,
    .StrongInline,
    .HighlightedInline,
    .SubscriptInline,
    .SuperscriptInline,
    .InsertInline,
    .DeleteInline,
    .FootnoteReferenceInline,
    .SpanInline,
    .SymbolsInline,
    .PipeTableSeparator,
    .SmartSymbolInline,
});

test "token" {
    try std.testing.expectEqual(tokens.SpanInline, opposite(opposite(tokens.SpanInline)));
}

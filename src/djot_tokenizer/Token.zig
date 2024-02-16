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

pub const tokens = enum { None, Ignore, DocumentBlock, HeadingBlock, QuoteBlock, ListItemBlock, CodeBlock, DivBlock, PipeTableBlock, ReferenceDefBlock, FootnoteDefBlock, ParagraphBlock, ThematicBreakToken, PipeTableCaptionBlock, Attribute, Padding, RawFormatInline, VerbatimInline, ImageSpanInline, LinkUrlInline, LinkReferenceInline, AutolinkInline, EscapedSymbolInline, EmphasisInline, StrongInline, HighlightedInline, SubscriptInline, SuperscriptInline, InsertInline, DeleteInline, FootnoteReferenceInline, SpanInline, SymbolsInline, PipeTableSeparator, SmartSymbolInline };

const std = @import("std");
const assert = std.testing.expect;
const token = @import("Token.zig");
const Attribute = @import("Attributes.zig").Attributes;

test "Test range" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    var ranges = token.Ranges.init(allocator);
    defer ranges.deinit();

    var range = token.Range{ .start = 0, .end = 10 };
    try ranges.push(range);
    try assert(ranges.ranges.items.len == 1);

    range = token.Range{ .start = 10, .end = 20 };
    try ranges.push(range);
    try assert(ranges.ranges.items.len == 1);

    range = token.Range{ .start = 15, .end = 25 };
    try ranges.push(range);
    try assert(ranges.ranges.items.len == 2);
}

test "Test token" {
    var tok = token.Token(isize).init(null, 0, 0);
    defer tok.deinit();

    tok.start = 0;
    tok.end = 3;
    try assert(tok.length() == 3);

    try assert(tok.isDefault());

    const document = "### Hello, World!";

    try assert(std.mem.eql(u8, tok.bytes(document), "###"));

    try assert(tok.prefixLength(document, '#') == 3);
}

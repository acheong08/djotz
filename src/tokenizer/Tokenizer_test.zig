const Attributes = @import("Attributes.zig").Attributes;
const AttributeEntry = @import("Attributes.zig").AttributeEntry;
const std = @import("std");
const assert = std.testing.expect;
const token = @import("Token.zig");
const Token = token.Token(isize);
const TokenList = @import("TokenList.zig").TokenList;
const TokenStack = @import("TokenStack.zig").TokenStack;

test "Attributes" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var gpalloc = gpa.allocator();

    var a = Attributes.init(gpalloc);

    try a.set("key1", "value1");
    try assert(a.size() == 1);
    try assert(std.mem.eql(u8, a.get("key1"), "value1"));

    try a.append("key1", "value2");
    try assert(a.size() == 1);
    try assert(std.mem.eql(u8, a.get("key1"), "value1 value2"));

    var b = Attributes.init(gpalloc);
    try b.set("key2", "value3");

    try a.mergeWith(&b);
    const attributeEntryBuf = try gpalloc.alloc(AttributeEntry, a.size());
    a.entries(attributeEntryBuf);
    try assert(std.mem.eql(u8, attributeEntryBuf[0].key, "key1"));
    try assert(std.mem.eql(u8, attributeEntryBuf[0].value, "value1 value2"));
    gpalloc.free(attributeEntryBuf);

    a.deinit();
    b.deinit();

    _ = gpa.deinit();
}

test "Token Range" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
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

test "Token" {
    var tok = Token.init(0, 0, 0);
    defer tok.deinit();

    tok.start = 0;
    tok.end = 3;
    try assert(tok.length() == 3);

    try assert(tok.isDefault());

    const document = "### Hello, World!";

    try assert(std.mem.eql(u8, tok.bytes(document), "###"));

    try assert(tok.prefixLength(document, '#') == 3);
}

test "TokenList" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var tokens = TokenList(isize).init(allocator);
    defer tokens.deinit();

    try tokens.push(Token.init(1, 0, 1));
    try tokens.push(Token.init(2, 10, 11));

    var expected = try allocator.alloc(Token, 3);
    defer allocator.free(expected);
    expected[0] = Token.init(1, 0, 1);
    expected[1] = Token.init(0, 1, 10);
    expected[2] = Token.init(2, 10, 11);

    try assert(tokens.items.items.len == 3);

    for (0..tokens.items.items.len) |i| {
        try std.testing.expectEqual(expected[i], tokens.items.items[i]);
    }
}

test "TokenStack 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var stack = TokenStack(isize).init(allocator);
    defer stack.deinit();

    try stack.openLevelAt(Token.init(2, 0, 1));
    try assert(stack.levels.items.len == 2);
    try stack.lastLevel().?.push(Token.init(10, 1, 4));
    try stack.closeLevelAt(Token.init(2 ^ 1, 10, 11));

    try assert(stack.lastLevel().?.items.items.len == 4);

    var expected = try allocator.alloc(Token, 4);
    defer allocator.free(expected);
    expected[0] = Token.init(2, 0, 1);
    expected[0].jumpToPair = 3;
    expected[1] = Token.init(10, 1, 4);
    expected[2] = Token.init(0, 4, 10);
    expected[3] = Token.init(2 ^ 1, 10, 11);
    expected[3].jumpToPair = -3;

    try assert(stack.lastLevel() != null);
    try std.testing.expectEqualSlices(Token, expected, stack.lastLevel().?.items.items);
}
test "TokenStack 2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var stack = TokenStack(isize).init(allocator);
    defer stack.deinit();

    try stack.openLevelAt(Token.init(2, 0, 0));
    try stack.openLevelAt(Token.init(4, 0, 1));
    try stack.openLevelAt(Token.init(6, 1, 2));
    try stack.openLevelAt(Token.init(8, 2, 3));
    var success = try stack.popForgetUntil(10);
    try assert(success == false);
    success = try stack.popForgetUntil(6);
    try assert(success == true);

    try stack.closeLevelAt(Token.init(6 ^ 1, 10, 11));
    try stack.popForget();
    try stack.closeLevelAt(Token.init(2 ^ 1, 11, 11));

    var expected = try allocator.alloc(Token, 6);
    defer allocator.free(expected);
    expected[0] = Token.init(2, 0, 0);
    expected[0].jumpToPair = 5;
    expected[1] = Token.init(0, 0, 1);
    expected[2] = Token.init(6, 1, 2);
    expected[2].jumpToPair = 2;
    expected[3] = Token.init(0, 2, 10);
    expected[4] = Token.init(6 ^ 1, 10, 11);
    expected[4].jumpToPair = -2;
    expected[5] = Token.init(2 ^ 1, 11, 11);
    expected[5].jumpToPair = -5;

    try std.testing.expectEqualSlices(Token, expected, stack.lastLevel().?.*.items.items);
}

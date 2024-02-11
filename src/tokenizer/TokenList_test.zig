const std = @import("std");
const assert = std.testing.expect;
const token = @import("Token.zig");
const TokenList = @import("TokenList.zig").TokenList;

test "TokenList" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var tokens = TokenList(isize).init(allocator);
    defer tokens.deinit();

    try tokens.push(token.Token(isize).init(1, 0, 1));
    try tokens.push(token.Token(isize).init(2, 10, 11));

    var expected = try allocator.alloc(token.Token(isize), 3);
    defer allocator.free(expected);
    expected[0] = token.Token(isize).init(1, 0, 1);
    expected[1] = token.Token(isize).init(null, 1, 10);
    expected[2] = token.Token(isize).init(2, 10, 11);

    try assert(tokens.items.items.len == 3);

    for (0..tokens.items.items.len) |i| {
        try std.testing.expectEqual(expected[i], tokens.items.items[i]);
    }
}

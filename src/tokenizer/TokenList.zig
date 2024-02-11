const std = @import("std");
const Token = @import("Token.zig").Token;

pub fn TokenList(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        items: std.ArrayList(Token(T)),

        pub fn init(allocator: std.mem.Allocator) TokenList(T) {
            return TokenList(T){
                .allocator = allocator,
                .items = std.ArrayList(Token(T)).init(allocator),
            };
        }

        pub fn deinit(self: *TokenList(T)) void {
            self.items.deinit();
        }

        pub fn firstOrDefault(self: *TokenList(T), t: *Token(T)) void {
            if (self.items.items.len == 0) {
                return;
            }
            t.* = self.items.items[0];
        }

        pub fn lastOrDefault(self: *TokenList(T), t: *Token(T)) void {
            if (self.items.items.len == 0) {
                return;
            }
            t.* = self.items.getLast();
        }

        pub fn fillUntil(self: *TokenList(T), position: usize, tokenType: ?T) !void {
            var last = Token(T).init(null, 0, 0);
            self.lastOrDefault(&last);
            if (self.items.items.len > 0 and last.end < position) {
                var newToken = Token(T){
                    .jumpToPair = null,
                    .attributes = null,
                    .start = last.end,
                    .end = position,
                    .tokenType = tokenType,
                };
                try self.items.append(newToken);
            }
        }

        pub fn push(self: *TokenList(T), token: Token(T)) !void {
            try self.fillUntil(token.start, null);
            try self.items.append(token);
        }
    };
}

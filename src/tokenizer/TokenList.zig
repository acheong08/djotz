const std = @import("std");
const Token = @import("Token.zig").Token;

fn defaultValue(comptime T: type) T {
    // Check if T is an enum
    if (@typeInfo(T) == .Enum) {
        return @enumFromInt(0);
    } else {
        return 0;
    }
}

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

        pub fn firstOrDefault(self: *const TokenList(T)) Token(T) {
            if (self.items.items.len == 0) {
                return Token(T).init(defaultValue(T), 0, 0);
            }
            return self.items.items[0];
        }

        pub fn lastOrDefault(self: *const TokenList(T)) Token(T) {
            if (self.items.items.len == 0) {
                return Token(T).init(defaultValue(T), 0, 0);
            }
            return self.items.getLast();
        }

        pub fn fillUntil(self: *TokenList(T), position: usize, tokenType: T) !void {
            const last = self.lastOrDefault();
            if (self.items.items.len > 0 and last.end < position) {
                const newToken = Token(T){
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
            try self.fillUntil(token.start, defaultValue(T));
            try self.items.append(token);
        }

        pub fn len(self: *const TokenList(T)) usize {
            return self.items.items.len;
        }
    };
}

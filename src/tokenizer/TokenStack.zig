const std = @import("std");
const TokenList = @import("TokenList.zig").TokenList;
const Token = @import("Token.zig").Token;

const Open: u8 = 1;

pub fn TokenStack(comptime T: type) type {
    return struct {
        levels: std.ArrayList(TokenList(T)),
        typeLevels: std.AutoHashMap(T, []const isize),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) TokenStack(T) {
            return TokenStack(T){
                .levels = std.ArrayList(TokenList(T)).init(allocator),
                .typeLevels = std.AutoHashMap(T, []const isize).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *TokenStack(T)) void {
            var typIter = self.typeLevels.iterator();
            while (typIter.next()) |lvl| {
                self.allocator.free(lvl.value_ptr.*);
            }
            for (0..self.levels.items.len) |i| {
                self.levels.items[i].deinit();
            }
            self.levels.deinit();
            self.typeLevels.deinit();
        }

        pub fn isEmpty(self: *const TokenStack(T)) bool {
            return self.typeLevels.count() == 0 and self.levels.items.len == 0 and self.levels.items[0].items.items.len == 0;
        }

        pub fn lastLevel(self: *const TokenStack(T)) ?TokenList(T) {
            return self.levels.getLastOrNull();
        }

        pub fn lastLevelPush(self: *TokenStack(T), token: Token(T)) void {
            if (self.levels.items.len == 0) {
                std.debug.panic("Cannot push to an empty stack", .{});
            }
            var lastLvl: TokenList(T) = self.allocator.dupe(TokenList(T), self.levels.getLast());
            lastLvl.push(token);
            self.allocator.free(self.levels.pop());
            self.levels.append(lastLvl);
        }

        pub fn popCommit(self: *TokenStack(T)) !void {
            if (self.levels.items.len <= 1) {
                std.debug.panic("Cannot pop the last level", .{});
            }
            const popLvl = self.lastLevel().?;
            var activeLvl: TokenList(T) = self.levels.pop();

            var firstPos: usize = 0;
            var lastPos: usize = 0;
            for (0..popLvl.len()) |i| {
                const token = popLvl.items.items[i];
                if (token.isDefault()) {
                    continue;
                }
                try activeLvl.push(token);
                if (i == 0) {
                    firstPos = activeLvl.len() - 1;
                }
                if (i == popLvl.len() - 1) {
                    lastPos = activeLvl.len() - 1;
                }
            }
            if (popLvl.firstOrDefault().tokenType ^ Open == popLvl.lastOrDefault().tokenType) {
                var lastLvl: TokenList(T) = self.levels.getLast();
                const jump = lastPos - firstPos;
                lastLvl.items.items[lastPos].jumpToPair = @intCast(jump);
                lastLvl.items.items[firstPos].jumpToPair = -lastLvl.items.items[lastPos].jumpToPair.?;
            }
            const typeLvls: ?[]const isize = self.typeLevels.get(popLvl.firstOrDefault().tokenType);
            if (typeLvls) |stypeLvls| {
                if (stypeLvls.len > 0) {
                    try self.typeLevels.put(popLvl.firstOrDefault().tokenType, stypeLvls[0 .. stypeLvls.len - 1]);
                }
            }
        }

        pub fn popForget(self: *TokenStack(T)) void {
            if (self.levels.items.len <= 0) {
                std.debug.panic("Cannot pop the last level");
            }
            const typeLvls: ?TokenList(T) = self.typeLevels.get(self.lastLevel().?.firstOrDefault().tokenType);
            if (typeLvls and typeLvls.?.len() > 0) {
                self.typeLevels.put(self.lastLevel().?.firstOrDefault().tokenType, typeLvls.?[0 .. typeLvls.?.len() - 1]);
            }
            const popLvl = self.lastLevel();
            const activeLvl: TokenList(T) = self.levels.pop();
            for (0..popLvl.?.len()) |i| {
                const token = popLvl.?.items[i];
                if (token.isDefault()) {
                    continue;
                }
                activeLvl.push(token);
            }
        }

        pub fn popForgetUntil(self: *TokenStack(T), tokenType: T) bool {
            const lvls: ?[]const u8 = self.typeLevels.get(tokenType);
            if (lvls == null or lvls.?.len() == 0) {
                return false;
            }
            const lastLvl = lvls.?[lvls.?.len - 1];
            while (self.levels.items.len > lastLvl + 1) {
                self.popForget();
            }
            return true;
        }

        pub fn openLevelAt(self: *TokenStack(T), token: Token(T)) !void {
            var newLvl = try self.allocator.alloc(isize, self.levels.items.len + 1);
            var currLvl = self.typeLevels.get(token.tokenType);
            if (currLvl) |lvl| {
                @memcpy(newLvl, lvl);
                self.allocator.free(lvl);
            }
            newLvl[newLvl.len - 1] = @intCast(self.levels.items.len);
            try self.typeLevels.put(token.tokenType, newLvl);

            var tokenList = TokenList(T).init(self.allocator);
            try self.levels.append(tokenList);
        }

        pub fn closeLevelAt(self: *TokenStack(T), token: Token(T)) !void {
            self.lastLevelPush(token);
            try self.popCommit();
        }
    };
}

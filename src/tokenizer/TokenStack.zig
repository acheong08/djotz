const std = @import("std");
const TokenList = @import("TokenList.zig").TokenList;
const Token = @import("Token.zig").Token;

const Open: u8 = 1;

fn opposite(comptime T: type, tokenType: T) T {
    if (@typeInfo(T) == .Enum) {
        return @enumFromInt(@intFromEnum(tokenType) ^ Open);
    }
    return tokenType ^ Open;
}

pub fn TokenStack(comptime T: type) type {
    return struct {
        levels: std.ArrayList(TokenList(T)),
        typeLevels: std.AutoHashMap(T, []const usize),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) TokenStack(T) {
            var ts = TokenStack(T){
                .levels = std.ArrayList(TokenList(T)).init(allocator),
                .typeLevels = std.AutoHashMap(T, []const usize).init(allocator),
                .allocator = allocator,
            };
            ts.levels.append(TokenList(T).init(allocator)) catch unreachable;
            return ts;
        }

        pub fn debugPrintLevels(self: *const TokenStack(T)) void {
            for (0..self.levels.items.len) |i| {
                const lvl: TokenList(T) = self.levels.items[i];
                for (0..lvl.items.items.len) |j| {
                    const token = lvl.items.items[j];
                    std.debug.print("\nLevel {any} Token {any} {any}\n", .{ i, j, token });
                }
            }
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

        pub fn lastLevel(self: *const TokenStack(T)) ?*TokenList(T) {
            return if (self.levels.items.len > 0) {
                return &self.levels.items[self.levels.items.len - 1];
            } else {
                return null;
            };
        }

        pub fn popCommit(self: *TokenStack(T)) !void {
            if (self.levels.items.len == 0) {
                std.debug.panic("Cannot pop the last level", .{});
            }
            var popLvl = self.levels.pop();
            var activeLvl: *TokenList(T) = self.lastLevel().?;
            defer popLvl.deinit();

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
            if (opposite(T, popLvl.firstOrDefault().tokenType) == popLvl.lastOrDefault().tokenType) {
                var lastLvl: TokenList(T) = self.levels.getLast();
                const jump: isize = @intCast(lastPos - firstPos);
                lastLvl.items.items[firstPos].jumpToPair = jump;
                lastLvl.items.items[lastPos].jumpToPair = -jump;
            }
            const typeLvls: ?[]const usize = self.typeLevels.get(popLvl.firstOrDefault().tokenType);
            if (typeLvls) |stypeLvls| {
                if (stypeLvls.len > 0) {
                    try self.typeLevels.put(popLvl.firstOrDefault().tokenType, stypeLvls[0 .. stypeLvls.len - 1]);
                    self.allocator.free(stypeLvls);
                }
            }
        }

        pub fn popForget(self: *TokenStack(T)) !void {
            if (self.levels.items.len <= 1) {
                std.debug.panic("Cannot pop the last level", .{});
            }
            const lastLvlType = self.levels.getLast().firstOrDefault().tokenType;
            const typeLvls: ?[]const usize = self.typeLevels.get(lastLvlType);
            if (typeLvls) |sTypeLvls| {
                if (sTypeLvls.len > 0) {
                    try self.typeLevels.put(lastLvlType, sTypeLvls[0 .. sTypeLvls.len - 1]);
                }
                self.allocator.free(sTypeLvls);
            }
            var popLvl: TokenList(T) = self.levels.pop();
            defer popLvl.deinit();
            var activeLvl: *TokenList(T) = self.lastLevel().?;
            for (1..popLvl.len()) |i| {
                var token = popLvl.items.items[i];
                if (token.isDefault()) {
                    continue;
                }
                try activeLvl.push(token);
            }
        }

        pub fn popForgetUntil(self: *TokenStack(T), tokenType: T) !bool {
            const lvls = self.typeLevels.get(tokenType);
            if (lvls == null or lvls.?.len == 0) {
                return false;
            }
            const lastLvl = lvls.?[lvls.?.len - 1];
            while (self.levels.items.len > lastLvl + 1) {
                try self.popForget();
            }
            return true;
        }

        pub fn openLevelAt(self: *TokenStack(T), token: Token(T)) !void {
            const currLvl: ?[]const usize = self.typeLevels.get(token.tokenType);
            var newLvl: []usize = try self.allocator.alloc(usize, if (currLvl) |scurrLvl| scurrLvl.len + 1 else 1);
            if (currLvl) |scurrLvl| {
                std.mem.copyForwards(usize, newLvl, scurrLvl);
                self.allocator.free(scurrLvl);
            }
            newLvl[newLvl.len - 1] = @intCast(self.levels.items.len);
            try self.typeLevels.put(token.tokenType, newLvl);

            var tokenList = TokenList(T).init(self.allocator);
            try tokenList.push(token);
            try self.levels.append(tokenList);
        }

        pub fn closeLevelAt(self: *TokenStack(T), token: Token(T)) !void {
            try self.lastLevel().?.push(token);
            try self.popCommit();
        }
    };
}

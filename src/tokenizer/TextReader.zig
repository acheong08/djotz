const std = @import("std");

const u64Len = @bitSizeOf(u64);

pub const ByteMask = struct {
    mask: [4]u64,

    pub fn init(set: []const u8) ByteMask {
        var mask: ByteMask = ByteMask{ .mask = [_]u64{ 0, 0, 0, 0 } };
        for (set) |b| {
            mask.mask[b / u64Len] |= @as(u64, 1) << @truncate(b);
        }
        return mask;
    }

    pub fn Has(self: *const ByteMask, b: u8) bool {
        return (self.mask[b / u64Len] & (@as(u64, 1) << @truncate(b))) > 0;
    }

    pub fn Negate(self: *const ByteMask) ByteMask {
        const mask: u64 = 0xFFFFFFFFFFFFFFFF;
        var bmask = ByteMask{ .mask = [_]u64{ 0, 0, 0, 0 } };
        inline for (0..4) |i| {
            bmask.mask[i] = self.mask[i] ^ mask;
        }
        return bmask;
    }

    pub fn Or(self: *const ByteMask, other: ByteMask) ByteMask {
        var mask: ByteMask = ByteMask{ .mask = [_]u64{ 0, 0, 0, 0 } };
        inline for (0..4) |i| {
            mask.mask[i] = self.mask[i] | other.mask[i];
        }
        return mask;
    }

    pub fn And(self: *const ByteMask, other: ByteMask) ByteMask {
        var mask: ByteMask = ByteMask{ .mask = [_]u64{ 0, 0, 0, 0 } };
        inline for (0..4) |i| {
            mask.mask[i] = self.mask[i] & other.mask[i];
        }
        return mask;
    }
};

pub fn Union(masks: ?[]const ByteMask) ByteMask {
    var mask: ByteMask = ByteMask{ .mask = [_]u64{ 0, 0, 0, 0 } };
    if (masks) |smasks| {
        for (smasks) |m| {
            mask = mask.Or(m);
        }
        return mask;
    } else {
        return mask;
    }
}

pub const SpaceByteMask = ByteMask.init(" \t");
pub const SpaceNewLineByteMask = ByteMask.init(" \t\r\n");

pub const TextReader = struct {
    doc: []const u8,

    pub fn init(doc: []const u8) TextReader {
        return TextReader{ .doc = doc };
    }

    pub fn select(self: *const TextReader, start: usize, end: usize) []const u8 {
        return self.doc[start..end];
    }

    pub fn emptyOrWhiteSpace(self: *const TextReader, state: usize) ?usize {
        const next = self.maskRepeat(state, SpaceNewLineByteMask, 0).?;
        if (!self.isEmpty(next)) {
            return null;
        }
        return next;
    }

    pub fn mask(self: *const TextReader, state: usize, mmask: ByteMask) ?usize {
        if (self.hasMask(state, mmask)) {
            return state + 1;
        }
        return null;
    }

    pub fn isEmpty(self: *const TextReader, state: usize) bool {
        return self.doc.len <= state;
    }

    pub fn hasMask(self: *const TextReader, state: usize, mmask: ByteMask) bool {
        if (self.isEmpty(state)) {
            return false;
        }
        return mmask.Has(self.doc[state]);
    }

    // comptime parameter should be optimized more aggressively by compiler (although LLVM should be able to correctly handle not comptime arg too)
    pub fn token(self: *const TextReader, state: usize, comptime ttoken: []const u8) ?usize {
        if (self.hasToken(state, ttoken)) {
            return state + ttoken.len;
        }
        return null;
    }

    pub fn hasToken(self: *const TextReader, state: usize, comptime ttoken: []const u8) bool {
        return std.mem.startsWith(u8, self.doc[state..], ttoken);
    }

    pub fn byteRepeat(self: *const TextReader, state: usize, b: u8, minCount: isize) ?usize {
        var newState = state;
        var newMinCount = minCount;
        while (!self.isEmpty(newState)) {
            if (self.hasByte(newState, b)) {
                newState += 1;
                newMinCount -= 1;
            } else {
                break;
            }
        }
        if (newMinCount <= 0) {
            return newState;
        }
        return null;
    }

    pub fn hasByte(self: *const TextReader, state: usize, b: u8) bool {
        if (self.isEmpty(state)) {
            return false;
        }
        return self.doc[state] == b;
    }

    pub fn maskRepeat(self: *const TextReader, state: usize, mmask: ByteMask, minCount: isize) ?usize {
        var newState = state;
        var newMinCount = minCount;
        while (self.hasMask(newState, mmask)) {
            newState += 1;
            newMinCount -= 1;
        }
        if (newMinCount > 0) {
            return null;
        }
        return newState;
    }

    pub fn peek(self: *const TextReader, state: usize) ?u8 {
        if (state < self.doc.len) {
            return self.doc[state];
        }
        return null;
    }
};

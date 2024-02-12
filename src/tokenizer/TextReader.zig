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
            bmask[i] = self.mask[i] ^ mask;
        }
        return bmask;
    }

    pub fn Or(self: *const ByteMask, other: ByteMask) ByteMask {
        var mask: ByteMask = ByteMask{ .mask = [_]u64{ 0, 0, 0, 0 } };
        inline for (0..4) |i| {
            mask[i] = self.mask[i] | other.mask[i];
        }
        return mask;
    }

    pub fn And(self: *const ByteMask, other: ByteMask) ByteMask {
        var mask: ByteMask = ByteMask{ .mask = [_]u64{ 0, 0, 0, 0 } };
        inline for (0..4) |i| {
            mask[i] = self.mask[i] & other.mask[i];
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

const spaceByteMask = ByteMask.init(" \t");
const SpaceNewLineByteMask = ByteMask.init(" \t\r\n");

pub const TextReader = struct {
    doc: []const u8,

    pub fn init(doc: []const u8) TextReader {
        return TextReader{ .doc = doc };
    }

    pub fn select(self: *const TextReader, start: usize, end: usize) []const u8 {
        return self.doc[start..end];
    }

    pub fn emptyOrWhiteSpace(self: *const TextReader, state: usize) struct { state: usize, empty: bool } {
        const next = self.maskRepeat(state, SpaceNewLineByteMask, 0).state;
        if (!self.isEmpty(next)) {
            return .{ .state = 0, .empty = false };
        }
        return .{ .state = next, .empty = true };
    }

    pub fn mask(self: *const TextReader, state: usize, mmask: ByteMask) struct { state: usize, found: bool } {
        if (self.hasMask(state, mmask)) {
            return .{ .state = state + 1, .found = true };
        }
        return .{ .state = 0, .found = false };
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

    pub fn token(self: *const TextReader, state: usize, ttoken: []const u8) struct { state: usize, found: bool } {
        if (self.hasToken(state, ttoken)) {
            return .{ .state = state + ttoken.len, .found = true };
        }
        return .{ .state = 0, .found = false };
    }

    pub fn hasToken(self: *const TextReader, state: usize, ttoken: []const u8) bool {
        return std.mem.startsWith(self.doc[state..], ttoken);
    }

    pub fn byteRepeat(self: *const TextReader, state: usize, b: u8, minCount: usize) struct { state: usize, min: bool } {
        while (!self.isEmpty(state)) {
            if (self.hasByte(state, b)) {
                state += 1;
                minCount -= 1;
            } else {
                break;
            }
        }
        if (minCount <= 0) {
            return .{ .state = state, .min = true };
        }
        return .{ .state = 0, .min = false };
    }

    pub fn hasByte(self: *const TextReader, state: usize, mmask: ByteMask) bool {
        if (self.isEmpty(state)) {
            return false;
        }
        return mmask.Has(self.doc[state]);
    }

    pub fn maskRepeat(self: *const TextReader, state: usize, mmask: ByteMask, minCount: usize) struct { state: usize, min: bool } {
        while (self.hasMask(state, mmask)) {
            state += 1;
            minCount -= 1;
        }
        return .{ .state = state, .min = (minCount <= 0) };
    }

    pub fn peek(self: *const TextReader, state: usize) struct { token: u8, ok: bool } {
        if (state < self.doc.len) {
            return .{ .token = self.doc[state], .ok = true };
        }
        return .{ .token = 0, .ok = false };
    }
};

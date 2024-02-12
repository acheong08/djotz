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

    pub fn has(m: *ByteMask, b: u8) bool {
        return (m.mask[b / u64Len] & (@as(u64, 1) << @truncate(b))) > 0;
    }

    pub fn negate(m: ByteMask) ByteMask {
        const mask: u64 = 0xFFFFFFFFFFFFFFFF;
        inline for (0..4) |i| {
            m.mask[i] = m.mask[i] ^ mask;
        }
        return m;
    }
};

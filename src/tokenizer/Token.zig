const std = @import("std");
const attributes = @import("Attributes.zig");

pub fn Token(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        tokenType: ?T,
        jumpToPair: isize,
        start: usize,
        end: usize,
        attributes: ?attributes.Attributes,

        pub fn init(allocator: std.mem.Allocator) Token(T) {
            return .{
                .allocator = allocator,
                .tokenType = null,
                .jumpToPair = 0,
                .start = 0,
                .end = 0,
                .attributes = null,
            };
        }

        pub fn deinit(self: *Token(T)) void {
            if (self.attributes != null) {
                self.attributes.?.deinit();
            }
        }

        pub fn length(self: *const Token(T)) usize {
            return self.end - self.start;
        }

        pub fn isDefault(self: *const Token(T)) bool {
            return self.tokenType == null;
        }

        pub fn bytes(self: *const Token(T), input: []const u8) []const u8 {
            return input[self.start..self.end];
        }

        pub fn prefixLength(self: *const Token(T), input: []const u8, b: u8) usize {
            const inputBytes = self.bytes(input);
            var i: usize = 0;
            while (i < inputBytes.len and inputBytes[i] == b) {
                i += 1;
            }
            return i;
        }
    };
}

pub const Range = struct {
    start: usize,
    end: usize,
};

pub const Ranges = struct {
    allocator: std.mem.Allocator,
    ranges: std.ArrayList(Range),

    pub fn init(allocator: std.mem.Allocator) Ranges {
        return Ranges{
            .allocator = allocator,
            .ranges = std.ArrayList(Range).init(allocator),
        };
    }

    pub fn deinit(self: *Ranges) void {
        self.ranges.deinit();
    }

    pub fn push(self: *Ranges, range: Range) !void {
        if (self.ranges.items.len == 0 or self.ranges.getLast().end != range.start) {
            try self.ranges.append(range);
        } else {
            const last = self.ranges.pop();
            try self.ranges.append(Range{ .start = last.start, .end = range.end });
        }
    }
};

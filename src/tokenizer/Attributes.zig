const std = @import("std");

pub const Attributes = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMap([]const u8),

    pub fn init(alloc: std.mem.Allocator) Attributes {
        return Attributes{
            .allocator = alloc,
            .map = std.StringHashMap([]const u8).init(alloc),
        };
    }

    pub fn deinit(self: *Attributes) void {
        var mapIt = self.map.iterator();
        while (mapIt.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn size(self: *const Attributes) usize {
        return self.map.count();
    }

    pub fn append(self: *Attributes, key: []const u8, value: []const u8) !void {
        if (self.map.get(key)) |prev| {
            // Concatenate the previous value with the new value
            var buf = try self.allocator.alloc(u8, prev.len + value.len + 1);
            _ = try std.fmt.bufPrint(buf, "{s} {s}", .{ prev, value });
            try self.map.put(key, buf);
            self.allocator.free(prev);
        } else {
            try self.set(key, value);
            return;
        }
    }

    pub fn set(self: *Attributes, key: []const u8, value: []const u8) !void {
        // Allocate a new copy of `value` so that all values in the map are managed consistently
        var allocValue = try self.allocator.alloc(u8, value.len);
        @memcpy(allocValue, value);

        // Optionally, check if the key exists and deallocate the old value before putting the new one
        if (self.map.get(key)) |oldValue| {
            self.allocator.free(oldValue);
        }

        try self.map.put(key, allocValue);
    }

    pub fn get(self: *const Attributes, key: []const u8) []const u8 {
        return self.map.get(key) orelse "";
    }
    pub fn mergeWith(self: *Attributes, other: *const Attributes) !void {
        var mapIt = other.map.iterator();
        while (mapIt.next()) |entry| {
            try self.set(entry.key_ptr.*, entry.value_ptr.*);
        }
    }
    pub fn entries(self: *const Attributes, buffer: []AttributeEntry) void {
        var mapIt = self.map.iterator();
        var i: usize = 0;
        while (mapIt.next()) |entry| {
            if (buffer.len <= i) {
                break;
            }
            buffer[i] = AttributeEntry{ .key = entry.key_ptr.*, .value = entry.value_ptr.* };
            i += 1;
        }
    }
};

pub const AttributeEntry = struct { key: []const u8, value: []const u8 };

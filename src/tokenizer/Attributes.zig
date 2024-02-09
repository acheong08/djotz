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
        var keyIterator = self.map.keyIterator();
        while (keyIterator.next()) |key| {
            const value = self.map.get(key.*) orelse continue;
            self.allocator.free(value);
        }
        self.map.deinit();
    }

    pub fn size(self: *const Attributes) usize {
        return self.map.count();
    }

    pub fn tryGet(self: *const Attributes, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }

    pub fn append(self: *Attributes, key: []const u8, value: []const u8) !void {
        const previous = self.tryGet(key);
        if (previous) |prev| {
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
        std.mem.copy(u8, allocValue, value);

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
        var keyIterator = other.map.keyIterator();
        while (keyIterator.next()) |key| {
            const value = other.map.get(key.*) orelse continue;
            try self.set(key.*, value);
        }
    }
    pub fn entries(self: *const Attributes, buffer: []AttributeEntry) void {
        var entriesIter = self.map.iterator();
        var i: usize = 0;
        while (entriesIter.next()) |entry| {
            if (buffer.len <= i) {
                break;
            }
            buffer[i] = AttributeEntry{ .key = entry.key_ptr.*, .value = entry.value_ptr.* };
            i += 1;
        }
    }
};

pub const AttributeEntry = struct { key: []const u8, value: []const u8 };

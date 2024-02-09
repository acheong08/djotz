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
        // Loop through the map and free all the values
        var keys = self.map.keyIterator();
        while (keys.next()) |key| {
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
        if (previous == null) {
            try self.map.put(key, value);
            return;
        }
        // Concatenate the previous value with the new value
        var buf = try self.allocator.alloc(u8, previous.?.len + value.len + 1);
        _ = try std.fmt.bufPrint(buf, "{s} {s}", .{ previous.?, value });
        try self.map.put(key, buf);
    }

    pub fn set(self: *Attributes, key: []const u8, value: []const u8) !void {
        try self.map.put(key, value);
    }

    pub fn get(self: *const Attributes, key: []const u8) []const u8 {
        return self.map.get(key) orelse "";
    }
    pub fn mergeWith(self: *Attributes, other: *const Attributes) void {
        var keyIterator = other.map.keyIterator();
        while (keyIterator.next()) |key| {
            const value = other.map.get(key) orelse continue;
            try self.set(key, value);
        }
    }
    pub fn entries(self: *const Attributes) []AttributeEntry {
        const keys = self.map.keyIterator();
        var entryList = []AttributeEntry{0};
        while (keys.next()) |key| {
            const value = self.map.get(key) orelse continue;
            entryList.append(AttributeEntry{ .key = key, .value = value });
        }
        return entryList;
    }
};

pub const AttributeEntry = struct { key: []const u8, value: []const u8 };

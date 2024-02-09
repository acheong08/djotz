const Attributes = @import("Attributes.zig").Attributes;
const std = @import("std");
const assert = std.testing.expect;

// Convert fixed size array to slice
pub fn toSlice(comptime T: type, comptime N: usize, arr: [N]T) ![]T {
    var slice: []T = undefined;
    try slice.init(arr[0..N]);
    return slice;
}

test "Buffer allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var a = gpa.allocator();

    var buf = try a.alloc(u8, 10);
    defer a.free(buf);
    try assert(buf.len == 10);
}

test "General Attributes test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var gpalloc = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(gpalloc);

    var a = Attributes.init(arena.allocator());
    defer {
        a.deinit();
        arena.deinit();
        const status = gpa.deinit();
        if (status == .leak) {
            std.debug.print("Memory leak detected\n", .{});
        }
    }

    try a.set("key1", "value1");
    try assert(a.size() == 1);
    try assert(std.mem.eql(u8, a.get("key1"), "value1"));

    try a.append("key1", "value2");
    try assert(a.size() == 1);
    try assert(std.mem.eql(u8, a.get("key1"), "value1 value2"));
}

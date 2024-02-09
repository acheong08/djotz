const Attributes = @import("Attributes.zig").Attributes;
const std = @import("std");
const assert = std.testing.expect;

test "General Attributes test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var gpalloc = gpa.allocator();

    var a = Attributes.init(gpalloc);

    try a.set("key1", "value1");
    try assert(a.size() == 1);
    try assert(std.mem.eql(u8, a.get("key1"), "value1"));

    try a.append("key1", "value2");
    try assert(a.size() == 1);
    try assert(std.mem.eql(u8, a.get("key1"), "value1 value2"));

    var b = Attributes.init(gpalloc);
    try b.set("key2", "value3");

    try a.mergeWith(&b);
    try assert(a.size() == 2);

    a.deinit();
    b.deinit();

    const status = gpa.deinit();
    if (status == .leak) {
        std.debug.print("Memory leak detected\n", .{});
    }
}

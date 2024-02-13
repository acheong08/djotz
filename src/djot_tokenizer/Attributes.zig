const std = @import("std");
const TextReader = @import("../tokenizer/TextReader.zig").TextReader;
const ByteMask = @import("../tokenizer/TextReader.zig").ByteMask;

const DjotAttributeClassKey = "class";
const DjotAttributeIdKey = "id";

pub fn matchQuotesString(allocator: std.mem.Allocator, reader: TextReader, state: usize) !struct { value: []const u8, state: usize, ok: bool } {
    const rawBytesMask = ByteMask.init("\\\"").Negate();

    const tok = reader.token(state, "\"");
    if (!tok.ok) {
        return .{ .value = undefined, .state = 0, .ok = false };
    }
    var value: []const u8 = undefined;
    var start = tok.state;
    var next = start;
    while (true) {
        const maskRet = reader.maskRepeat(next, rawBytesMask, 0);
        next = maskRet.state;
        const tmpDoc = reader.doc[start..next];
        if (value == undefined) {
            value = allocator.dupe(u8, tmpDoc);
        } else {
            const newValue = try std.mem.concat(allocator, value, tmpDoc);
            allocator.free(value);
            value = newValue;
        }
        var ttok = reader.token(next, "\"");
        if (ttok.ok) {
            return .{ .value = value, .state = ttok.state, .ok = true };
        }
        ttok = reader.token(next, "\\");
        if (ttok.ok) {
            if (reader.isEmpty(ttok.state)) {
                return .{ .value = undefined, .state = 0, .ok = false };
            }
            allocator.realloc(value, value.len + 1);
            value[value.len - 1] = reader.doc[ttok.state];
            start = ttok.state + 1;
            next = start;
        } else {
            return .{ .value = undefined, .state = 0, .ok = false };
        }
    }
}

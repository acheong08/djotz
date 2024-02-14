const std = @import("std");
const TextReader = @import("../tokenizer/TextReader.zig").TextReader;
const ByteMask = @import("../tokenizer/TextReader.zig").ByteMask;
const Attributes = @import("../tokenizer/Attributes.zig").Attributes;

const DjotAttributeClassKey = "class";
const DjotAttributeIdKey = "id";

pub fn matchQuotesString(allocator: std.mem.Allocator, reader: TextReader, state: usize) !struct { value: []const u8, state: usize, ok: bool } {
    const fail = .{ .value = undefined, .state = 0, .ok = false };
    const rawBytesMask = ByteMask.init("\\\"").Negate();

    const tok = reader.token(state, "\"");
    if (!tok.ok) {
        return fail;
    }
    var value: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(value);
    var start = tok.state;
    var next = start;
    while (true) {
        const tmp = reader.maskRepeat(next, rawBytesMask, 0);
        if (!tmp.ok) {
            std.debug.panic("MaskRepeat must match because minCount is zero", .{});
        }
        next = tmp.state;
        // value = append(value, r[start:next]...)
        {
            const tmpDoc = reader.doc[start..next];
            const newValue: []u8 = try allocator.alloc(u8, value.len + tmpDoc.len);
            _ = try std.fmt.bufPrint(newValue, "{s}{s}", .{ value, tmpDoc });
            allocator.free(value);
            value = newValue;
        }

        var ttok = reader.token(next, "\"");
        if (ttok.ok) {
            const valueCpy = try allocator.dupe(u8, value);
            return .{ .value = valueCpy, .state = ttok.state, .ok = true };
        }
        ttok = reader.token(next, "\\");
        if (ttok.ok) {
            if (reader.isEmpty(ttok.state)) {
                return fail;
            }
            const newValue = try allocator.alloc(u8, value.len + 1);
            _ = try std.fmt.bufPrint(newValue, "{s}", .{value});
            allocator.free(value);
            value = newValue;
            value[value.len - 1] = reader.doc[ttok.state];
            start = ttok.state + 1;
            next = start;
        } else {
            return fail;
        }
    }
}

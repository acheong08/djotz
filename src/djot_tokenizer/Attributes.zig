const std = @import("std");
const TextReader = @import("../tokenizer/TextReader.zig").TextReader;
const ByteMask = @import("../tokenizer/TextReader.zig").ByteMask;
const Attributes = @import("../tokenizer/Attributes.zig").Attributes;
const SpaceNewLineByteMask = @import("../tokenizer/TextReader.zig").SpaceNewLineByteMask;
const masks = @import("BlockToken.zig");

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

pub fn matchDjotAttribute(allocator: std.mem.Allocator, reader: TextReader, state: usize) !struct { attributes: Attributes, state: usize, ok: bool } {
    const fail = .{ .attributes = undefined, .state = 0, .ok = false };
    const tok = reader.token(state, "{");
    if (!tok.ok) {
        return fail;
    }
    var attributes = Attributes.init(allocator);
    var comment = false;
    var next = tok.state;
    while (true) {
        {
            const ttok = reader.maskRepeat(next, SpaceNewLineByteMask, 0);
            if (!ttok.ok) {
                std.debug.panic("MaskRepeat must match because minCount is zero", .{});
                next = ttok.state;
            }
        }
        if (reader.isEmpty(next)) {
            return fail;
        }
        var ttok = reader.token(next, "%");
        if (ttok.ok) {
            comment = ttok.state != 0;
            next = ttok.state;
            continue;
        }
        if (comment) {
            next += 1;
            continue;
        }
        ttok = reader.token(next, "}");
        if (ttok.ok) {
            return .{ .attributes = attributes, .state = ttok.state, .ok = true };
        }

        ttok = reader.token(next, ".");
        if (ttok.ok) {
            const mr = reader.maskRepeat(ttok.state, masks.AttributeTokenMask, 1);
            if (!mr.ok) {
                return fail;
            }
            const className = reader.select(ttok.state, next);
            attributes.append(DjotAttributeClassKey, className);
            continue;
        } else {
            ttok = reader.token(next, "#");
            if (ttok.ok) {
                const mr = reader.maskRepeat(ttok.state, masks.AttributeTokenMask, 1);
                if (!mr.ok) {
                    return fail;
                }
                attributes.append(DjotAttributeIdKey, reader.select(ttok.state, next));
                continue;
            }
        }
        const startKey = next;
        var mr = reader.maskRepeat(next, masks.AttributeTokenMask, 1);
        if (!mr.ok) {
            return fail;
        }
        next = mr.state;
        const endKey = next;

        ttok = reader.token(next, "=");
        if (!ttok.ok) {
            return fail;
        }
        next = ttok.state;

        const startValue = next;

        const match = matchQuotesString(allocator, reader, next);
        if (match.ok) {
            attributes.set(reader.select(startKey, endKey), match.value);
            allocator.free(match.value);
            next = match.state;
        } else {
            mr = reader.maskRepeat(next, masks.AttributeTokenMask, 1);
            if (!mr.ok) {
                return fail;
            }
            next = mr.state;
            try attributes.set(reader.select(startKey, endKey), reader.select(startValue, next));
        }
    }
}

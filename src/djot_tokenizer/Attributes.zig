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

const matchDjotAttrRetType = struct {
    state: usize,
    ok: bool,
};

pub fn matchDjotAttribute(reader: TextReader, state: usize, attributes: *Attributes) !matchDjotAttrRetType {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const startToken = reader.token(state, "{");
    if (!startToken.ok) {
        return .{ .state = 0, .ok = false };
    }

    const fail = .{ .state = 0, .ok = false };

    var comment = false;
    var next = startToken.state;
    while (true) {
        var mr = reader.maskRepeat(next, SpaceNewLineByteMask, 0);
        if (!mr.ok) {
            std.debug.panic("MaskRepeat must match because minCount is zero", .{});
        }
        next = mr.state;
        if (reader.isEmpty(next)) {
            return fail;
        }
        const commentToken = reader.token(next, "%");
        if (commentToken.ok) {
            comment = !comment;
            next = commentToken.state;
            continue;
        }
        if (comment) {
            next += 1;
            continue;
        }
        const endToken = reader.token(next, "}");
        if (endToken.ok) {
            return .{ .state = endToken.state, .ok = true };
        }

        const classToken = reader.token(next, ".");
        if (classToken.ok) {
            mr = reader.maskRepeat(classToken.state, masks.AttributeTokenMask, 1);
            if (!mr.ok) {
                return fail;
            }
            next = mr.state;
            const className = reader.select(classToken.state, next);
            try attributes.append(DjotAttributeClassKey, className);
            continue;
        } else {
            const idToken = reader.token(next, "#");
            if (idToken.ok) {
                mr = reader.maskRepeat(idToken.state, masks.AttributeTokenMask, 1);
                if (!mr.ok) {
                    return fail;
                }
                next = mr.state;
                try attributes.set(DjotAttributeIdKey, reader.select(idToken.state, next));
                continue;
            }
        }
        const startKey = next;
        mr = reader.maskRepeat(next, masks.AttributeTokenMask, 1);
        if (!mr.ok) {
            return fail;
        }
        next = mr.state;
        const endKey = next;

        const equalityToken = reader.token(next, "=");
        if (!equalityToken.ok) {
            return fail;
        }
        next = equalityToken.state;

        const startValue = next;

        const match = try matchQuotesString(allocator, reader, next);
        if (match.ok) {
            try attributes.set(reader.select(startKey, endKey), match.value);
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

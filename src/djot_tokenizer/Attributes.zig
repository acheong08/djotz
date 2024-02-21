const std = @import("std");
const TextReader = @import("../tokenizer/TextReader.zig").TextReader;
const ByteMask = @import("../tokenizer/TextReader.zig").ByteMask;
pub const Attributes = @import("../tokenizer/Attributes.zig").Attributes;
const SpaceNewLineByteMask = @import("../tokenizer/TextReader.zig").SpaceNewLineByteMask;
const masks = @import("BlockToken.zig");

pub const DjotAttributeClassKey = "class";
pub const DjotAttributeIdKey = "id";

pub fn matchQuotesString(allocator: std.mem.Allocator, reader: TextReader, state: usize) !?struct { value: []const u8, state: usize } {
    const rawBytesMask = ByteMask.init("\\\"").Negate();

    const tok = reader.token(state, "\"");
    if (tok == null) {
        return null;
    }
    var value: []u8 = try allocator.alloc(u8, 0);
    defer allocator.free(value);
    var start = tok.?;
    var next = start;
    while (true) {
        const tmp = reader.maskRepeat(next, rawBytesMask, 0);
        if (tmp == null) {
            std.debug.panic("MaskRepeat must match because minCount is zero", .{});
        }
        next = tmp.?;
        // value = append(value, r[start:next]...)
        {
            const tmpDoc = reader.doc[start..next];
            const newValue: []u8 = try allocator.alloc(u8, value.len + tmpDoc.len);
            _ = try std.fmt.bufPrint(newValue, "{s}{s}", .{ value, tmpDoc });
            allocator.free(value);
            value = newValue;
        }

        var ttok = reader.token(next, "\"");
        if (ttok != null) {
            const valueCpy = try allocator.dupe(u8, value);
            return .{ .value = valueCpy, .state = ttok.? };
        }
        ttok = reader.token(next, "\\");
        if (ttok != null) {
            if (reader.isEmpty(ttok.?)) {
                return null;
            }
            const newValue = try allocator.alloc(u8, value.len + 1);
            _ = try std.fmt.bufPrint(newValue, "{s}", .{value});
            allocator.free(value);
            value = newValue;
            value[value.len - 1] = reader.doc[ttok.?];
            start = ttok.? + 1;
            next = start;
        } else {
            return null;
        }
    }
}

pub fn matchDjotAttribute(reader: TextReader, state: usize, attributes: *Attributes) !?usize {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const startToken = reader.token(state, "{");
    if (startToken == null) {
        return null;
    }

    var comment = false;
    var next = startToken.?;
    while (true) {
        var mr = reader.maskRepeat(next, SpaceNewLineByteMask, 0);
        if (mr == null) {
            std.debug.panic("MaskRepeat must match because minCount is zero", .{});
        }
        next = mr.?;
        if (reader.isEmpty(next)) {
            return null;
        }
        const commentToken = reader.token(next, "%");
        if (commentToken != null) {
            comment = !comment;
            next = commentToken.?;
            continue;
        }
        if (comment) {
            next += 1;
            continue;
        }
        const endToken = reader.token(next, "}");
        if (endToken != null) {
            return endToken.?;
        }

        const classToken = reader.token(next, ".");
        if (classToken != null) {
            mr = reader.maskRepeat(classToken.?, masks.AttributeTokenMask, 1);
            if (mr == null) {
                return null;
            }
            next = mr.?;
            const className = reader.select(classToken.?, next);
            try attributes.append(DjotAttributeClassKey, className);
            continue;
        } else {
            const idToken = reader.token(next, "#");
            if (idToken != null) {
                mr = reader.maskRepeat(idToken.?, masks.AttributeTokenMask, 1);
                if (mr == null) {
                    return null;
                }
                next = mr.?;
                try attributes.set(DjotAttributeIdKey, reader.select(idToken.?, next));
                continue;
            }
        }
        const startKey = next;
        mr = reader.maskRepeat(next, masks.AttributeTokenMask, 1);
        if (mr == null) {
            return null;
        }
        next = mr.?;
        const endKey = next;

        const equalityToken = reader.token(next, "=");
        if (equalityToken == null) {
            return null;
        }
        next = equalityToken.?;

        const startValue = next;

        const match = try matchQuotesString(allocator, reader, next);
        if (match != null) {
            try attributes.set(reader.select(startKey, endKey), match.?.value);
            allocator.free(match.?.value);
            next = match.?.state;
        } else {
            mr = reader.maskRepeat(next, masks.AttributeTokenMask, 1);
            if (mr == null) {
                return null;
            }
            next = mr.?;
            try attributes.set(reader.select(startKey, endKey), reader.select(startValue, next));
        }
    }
}

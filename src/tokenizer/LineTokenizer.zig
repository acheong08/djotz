const std = @import("std");

const newLine: []const u8 = "\n";

pub const LineTokenizer = struct {
    document: []const u8,
    docOffset: usize,

    pub fn init(document: []const u8) LineTokenizer {
        return .{ .document = document, .docOffset = 0 };
    }

    pub fn scan(self: *LineTokenizer) ?struct { start: usize, end: usize } {
        if (self.docOffset >= self.document.len) {
            return null;
        }
        const suffix = self.document[self.docOffset..];
        const newLineIndex = std.mem.indexOf(u8, suffix, newLine);
        if (newLineIndex == null) {
            const ret = .{ .start = self.docOffset, .end = self.document.len };
            self.docOffset = self.document.len;
            return ret;
        }
        const ret = .{ .start = self.docOffset, .end = self.docOffset + newLineIndex.? + 1 };
        self.docOffset += newLineIndex.? + 1;
        return ret;
    }
};

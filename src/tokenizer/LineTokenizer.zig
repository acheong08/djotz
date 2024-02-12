const std = @import("std");

const newLine: []const u8 = "\n";

pub const LineTokenizer = struct {
    document: []const u8,
    docOffset: usize,

    pub fn init(document: []const u8) LineTokenizer {
        return .{ .document = document, .docOffset = 0 };
    }

    pub fn scan(self: *LineTokenizer) struct { start: usize, end: usize, eof: bool } {
        if (self.docOffset >= self.document.len) {
            return .{ .start = 0, .end = 0, .eof = true };
        }
        const suffix = self.document[self.docOffset..];
        const newLineIndex = std.mem.indexOf(u8, suffix, newLine);
        if (newLineIndex == null) {
            const ret = .{ .start = self.docOffset, .end = self.document.len, .eof = false };
            self.docOffset = self.document.len;
            return ret;
        }
        const ret = .{ .start = self.docOffset, .end = self.docOffset + newLineIndex.? + 1, .eof = false };
        self.docOffset += newLineIndex.? + 1;
        return ret;
    }
};

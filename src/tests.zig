const Attributes = @import("tokenizer/Attributes.zig").Attributes;
const AttributeEntry = @import("tokenizer/Attributes.zig").AttributeEntry;
const std = @import("std");
const assert = std.testing.expect;
const token = @import("tokenizer/Token.zig");
const Token = token.Token(isize);
const TokenList = @import("tokenizer/TokenList.zig").TokenList;
const TokenStack = @import("tokenizer/TokenStack.zig").TokenStack;
const LineTokenizer = @import("tokenizer/LineTokenizer.zig").LineTokenizer;
const ByteMask = @import("tokenizer/TextReader.zig").ByteMask;
const ByteMaskUnion = @import("tokenizer/TextReader.zig").Union;
const TextReader = @import("tokenizer/TextReader.zig").TextReader;

test "Attributes" {
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
    const attributeEntryBuf = try gpalloc.alloc(AttributeEntry, a.size());
    a.entries(attributeEntryBuf);
    try assert(std.mem.eql(u8, attributeEntryBuf[0].key, "key1"));
    try assert(std.mem.eql(u8, attributeEntryBuf[0].value, "value1 value2"));
    gpalloc.free(attributeEntryBuf);

    a.deinit();
    b.deinit();

    _ = gpa.deinit();
}

test "Token Range" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var ranges = token.Ranges.init(allocator);
    defer ranges.deinit();

    var range = token.Range{ .start = 0, .end = 10 };
    try ranges.push(range);
    try assert(ranges.ranges.items.len == 1);

    range = token.Range{ .start = 10, .end = 20 };
    try ranges.push(range);
    try assert(ranges.ranges.items.len == 1);

    range = token.Range{ .start = 15, .end = 25 };
    try ranges.push(range);
    try assert(ranges.ranges.items.len == 2);
}

test "Token" {
    var tok = Token.init(0, 0, 0);
    defer tok.deinit();

    tok.start = 0;
    tok.end = 3;
    try assert(tok.length() == 3);

    try assert(tok.isDefault());

    const document = "### Hello, World!";

    try assert(std.mem.eql(u8, tok.bytes(document), "###"));

    try assert(tok.prefixLength(document, '#') == 3);
}

test "TokenList" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var tokens = TokenList(isize).init(allocator);
    defer tokens.deinit();

    try tokens.push(Token.init(1, 0, 1));
    try tokens.push(Token.init(2, 10, 11));

    var expected = try allocator.alloc(Token, 3);
    defer allocator.free(expected);
    expected[0] = Token.init(1, 0, 1);
    expected[1] = Token.init(0, 1, 10);
    expected[2] = Token.init(2, 10, 11);

    try assert(tokens.items.items.len == 3);

    for (0..tokens.items.items.len) |i| {
        try std.testing.expectEqual(expected[i], tokens.items.items[i]);
    }
}

test "TokenStack 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var stack = TokenStack(isize).init(allocator);
    defer stack.deinit();

    try stack.openLevelAt(Token.init(2, 0, 1));
    try assert(stack.levels.items.len == 2);
    try stack.lastLevel().?.push(Token.init(10, 1, 4));
    try stack.closeLevelAt(Token.init(2 ^ 1, 10, 11));

    try assert(stack.lastLevel().?.items.items.len == 4);

    var expected = try allocator.alloc(Token, 4);
    defer allocator.free(expected);
    expected[0] = Token.init(2, 0, 1);
    expected[0].jumpToPair = 3;
    expected[1] = Token.init(10, 1, 4);
    expected[2] = Token.init(0, 4, 10);
    expected[3] = Token.init(2 ^ 1, 10, 11);
    expected[3].jumpToPair = -3;

    try assert(stack.lastLevel() != null);
    try std.testing.expectEqualSlices(Token, expected, stack.lastLevel().?.items.items);
}
test "TokenStack 2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var stack = TokenStack(isize).init(allocator);
    defer stack.deinit();

    try stack.openLevelAt(Token.init(2, 0, 0));
    try stack.openLevelAt(Token.init(4, 0, 1));
    try stack.openLevelAt(Token.init(6, 1, 2));
    try stack.openLevelAt(Token.init(8, 2, 3));
    var success = try stack.popForgetUntil(10);
    try assert(success == false);
    success = try stack.popForgetUntil(6);
    try assert(success == true);

    try stack.closeLevelAt(Token.init(6 ^ 1, 10, 11));
    try stack.popForget();
    try stack.closeLevelAt(Token.init(2 ^ 1, 11, 11));

    var expected = try allocator.alloc(Token, 6);
    defer allocator.free(expected);
    expected[0] = Token.init(2, 0, 0);
    expected[0].jumpToPair = 5;
    expected[1] = Token.init(0, 0, 1);
    expected[2] = Token.init(6, 1, 2);
    expected[2].jumpToPair = 2;
    expected[3] = Token.init(0, 2, 10);
    expected[4] = Token.init(6 ^ 1, 10, 11);
    expected[4].jumpToPair = -2;
    expected[5] = Token.init(2 ^ 1, 11, 11);
    expected[5].jumpToPair = -5;

    try std.testing.expectEqualSlices(Token, expected, stack.lastLevel().?.*.items.items);
}

test "Line Tokenizer" {
    const document: []const u8 = "hello\nworld\n!";
    var tokenizer = LineTokenizer.init(document);
    var ret = tokenizer.scan();
    try assert(ret.eof == false);
    try std.testing.expectEqualStrings("hello\n", document[ret.start..ret.end]);
    ret = tokenizer.scan();
    try assert(ret.eof == false);
    try std.testing.expectEqualStrings("world\n", document[ret.start..ret.end]);
    ret = tokenizer.scan();
    try assert(ret.eof == false);
    try std.testing.expectEqualStrings("!", document[ret.start..ret.end]);
    ret = tokenizer.scan();
    try assert(ret.eof == true);
}

test "ByteMask" {
    var mask = ByteMask.init(&[_]u8{ 1, 2, 3, 4, 5 });
    try assert(mask.Has(1));
    try assert(mask.Has(2));
    try assert(!mask.Has(6));

    var negated = mask.Negate();
    try assert(!negated.Has(1));
    try assert(!negated.Has(2));
    try assert(negated.Has(6));

    var mask2 = ByteMask.init(&[_]u8{ 6, 7, 8, 9, 10 });
    var orMask = mask.Or(mask2);
    try assert(orMask.Has(1));
    try assert(orMask.Has(2));
    try assert(orMask.Has(6));
    try assert(orMask.Has(7));

    var andMask = mask.And(mask2);
    try assert(!andMask.Has(1));
    try assert(!andMask.Has(2));
    try assert(!andMask.Has(6));
    try assert(!andMask.Has(7));

    const mask1 = ByteMask.init(&[_]u8{ 1, 2, 3, 4, 5 });
    mask2 = ByteMask.init(&[_]u8{ 6, 7, 8, 9, 10 });
    const mask3 = ByteMask.init(&[_]u8{ 11, 12, 13, 14, 15 });

    var unionMask = ByteMaskUnion(&[_]ByteMask{ mask1, mask2, mask3 });

    try assert(unionMask.Has(1));
    try assert(unionMask.Has(2));
    try assert(unionMask.Has(6));
    try assert(unionMask.Has(7));
    try assert(unionMask.Has(11));
    try assert(unionMask.Has(12));
    try assert(!unionMask.Has(16));
}

test "TextReader" {
    var reader = TextReader.init("Hello, World!");

    try std.testing.expectEqualStrings(reader.select(0, 5), "Hello");
    try std.testing.expectEqualStrings(reader.select(7, 12), "World");

    var result = reader.emptyOrWhiteSpace(0);
    try assert(result.state == 0);
    try assert(result.empty == false);

    result = reader.emptyOrWhiteSpace(13);
    try assert(result.state == 13);
    try assert(result.empty == true);

    var maskResult = reader.mask(0, ByteMask.init("H"));
    try assert(maskResult.state == 1);
    try assert(maskResult.ok == true);

    maskResult = reader.mask(0, ByteMask.init("Z"));
    try assert(maskResult.state == 0);
    try assert(maskResult.ok == false);

    var tokenResult = reader.token(0, "Hello");
    try assert(tokenResult.state == 5);
    try assert(tokenResult.ok == true);

    tokenResult = reader.token(0, "World");
    try assert(tokenResult.state == 0);
    try assert(tokenResult.ok == false);

    var repeatResult = reader.byteRepeat(0, 'l', 2);
    try assert(repeatResult.state == 0);
    try assert(repeatResult.min == false);

    repeatResult = reader.byteRepeat(2, 'l', 2);
    try assert(repeatResult.state == 4);
    try assert(repeatResult.min == true);

    var peekResult = reader.peek(0);
    try assert(peekResult.token == 'H');
    try assert(peekResult.ok == true);

    peekResult = reader.peek(13);
    try assert(peekResult.token == 0);
    try assert(peekResult.ok == false);
}

const DjotAttributes = @import("djot_tokenizer/Attributes.zig");

test "Matched Quoted String" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const testValue: type = struct {
        s: []const u8,
        value: []const u8,
    };
    const testValues = [_]testValue{
        testValue{ .s = "\"hello\"", .value = "hello" },
        testValue{ .s = "\"\"", .value = undefined },
        testValue{ .s = "\"this is (\\\") quote \"", .value = "this is (\") quote " },
    };
    for (testValues) |testVal| {
        const reader = TextReader.init(testVal.s);
        const result = try DjotAttributes.matchQuotesString(allocator, reader, 0);
        try assert(result.ok);
        try assert(testVal.s.len == result.state);
        try std.testing.expectEqualStrings(testVal.value, result.value);
        allocator.free(result.value);
    }
}

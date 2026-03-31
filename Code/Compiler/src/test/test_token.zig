const std = @import("std");
const tok = @import("../token.zig");
const bitset = @import("../bitset.zig");

const TK = tok.Kind;
const Token = tok.Token;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Test token sizes" {
    try expect(@bitSizeOf(Token) == 64);
    try expect(@bitSizeOf(Token) == 64);
}

test "Test precedence table" {
    const dotFlush = tok.TBL_PRECEDENCE_FLUSH[@intFromEnum(TK.op_dot_member)];
    try expectEqual(1, dotFlush.count());

    const divFlush = tok.TBL_PRECEDENCE_FLUSH[@intFromEnum(TK.op_div)];
    try expectEqual(7, divFlush.count()); // 7 higher/equal precedence operators.
    // When you see a div, flush all of these operators (but not lower precedence ones like add, sub, etc.)
    const divFlushExpected = bitset.token_bitset(&[_]TK{ TK.op_mod, TK.op_div, TK.op_mul, TK.op_pow, TK.op_unary_minus, TK.op_not, TK.op_dot_member });
    try expectEqual(divFlushExpected.mask, divFlush.mask);

    // Test right-associative. Should not flush itself.
    const powFlush = tok.TBL_PRECEDENCE_FLUSH[@intFromEnum(TK.op_pow)];
    try expectEqual(3, powFlush.count());
    const powFlushExpected = bitset.token_bitset(&[_]TK{ TK.op_dot_member, TK.op_unary_minus, TK.op_not });
    try expectEqual(powFlushExpected.mask, powFlush.mask);
}

test "Test fast inverse comparison" {
    const table = tok.getInverseComparisonLookupTable();
    try expectEqual(0x20010000a7c, table);
    try expectEqual(tok.inverseComparison(TK.op_dbl_eq), TK.op_not_eq);
    try expectEqual(tok.inverseComparison(TK.op_not_eq), TK.op_dbl_eq);
    try expectEqual(tok.inverseComparison(TK.op_lt), TK.op_gte);
    try expectEqual(tok.inverseComparison(TK.op_gte), TK.op_lt);
    try expectEqual(tok.inverseComparison(TK.op_gt), TK.op_lte);
    try expectEqual(tok.inverseComparison(TK.op_lte), TK.op_gt);
}

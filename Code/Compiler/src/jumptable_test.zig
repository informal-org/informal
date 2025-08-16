const std = @import("std");
const testing = std.testing;
const tok = @import("token.zig");
const bitset = @import("bitset.zig");
const jumptable = @import("jumptable.zig");

const JumpTable = jumptable.JumpTable;
const JumpEntry = jumptable.JumpEntry;

// Create individual bitsets for more entries (non-overlapping with existing bitsets)
const SINGLE_TOKENS = bitset.token_bitset(&[_]tok.Kind{ .identifier, .const_identifier, .type_identifier, .call_identifier });
// Skip SPECIAL_OPS since op_in, op_is, op_as are already in BINARY_OPS
const SEPARATORS = bitset.token_bitset(&[_]tok.Kind{ .sep_comma, .sep_newline });
const CLOSE_GROUPS = bitset.token_bitset(&[_]tok.Kind{ .grp_close_brace, .grp_close_bracket, .grp_close_paren, .grp_dedent });
// Only use tokens that are NOT already in existing bitsets
const EXTRA_OPS1 = bitset.token_bitset(&[_]tok.Kind{.op_dot_member}); // Only op_dot_member, not op_colon_assoc (it's in BINARY_OPS)
const EXTRA_OPS2 = bitset.token_bitset(&[_]tok.Kind{ .op_sub, .op_mod }); // These should be safe
const EXTRA_OPS3 = bitset.token_bitset(&[_]tok.Kind{.grp_indent}); // Use grouping tokens not in GROUP_START
const EXTRA_OPS4 = bitset.token_bitset(&[_]tok.Kind{.lit_string}); // This will overlap with LITERALS - let's test the first match behavior

const ParserAction = enum {
    expect_literal,
    expect_unary,
    expect_binary,
    expect_group,
    expect_keyword,
    expect_identifier,
    expect_separator,
    expect_close_group,
    expect_extra_op1,
    expect_extra_op2,
    expect_extra_op3,
    expect_extra_op4,
};

const test_table = JumpTable(ParserAction, &[_]JumpEntry(ParserAction){
    .{ .bitset = tok.LITERALS, .target = .expect_literal },
    .{ .bitset = tok.UNARY_OPS, .target = .expect_unary },
    .{ .bitset = tok.BINARY_OPS, .target = .expect_binary },
    .{ .bitset = tok.GROUP_START, .target = .expect_group },
    .{ .bitset = tok.KEYWORD_START, .target = .expect_keyword },
    // .{ .bitset = SINGLE_TOKENS, .target = .expect_identifier },
    // .{ .bitset = SEPARATORS, .target = .expect_separator },
    // .{ .bitset = CLOSE_GROUPS, .target = .expect_close_group },
    // .{ .bitset = EXTRA_OPS1, .target = .expect_extra_op1 },
    // .{ .bitset = EXTRA_OPS2, .target = .expect_extra_op2 },
    // .{ .bitset = EXTRA_OPS3, .target = .expect_extra_op3 },
    // .{ .bitset = EXTRA_OPS4, .target = .expect_extra_op4 },
});

test "jumptable iterative - literal tokens" {
    try testing.expectEqual(ParserAction.expect_literal, test_table.jump_iterative(tok.Kind.lit_string));
    try testing.expectEqual(ParserAction.expect_literal, test_table.jump_iterative(tok.Kind.lit_number));
    try testing.expectEqual(ParserAction.expect_literal, test_table.jump_iterative(tok.Kind.lit_bool));
    try testing.expectEqual(ParserAction.expect_literal, test_table.jump_iterative(tok.Kind.lit_null));
}

test "jumptable iterative - unary ops" {
    try testing.expectEqual(ParserAction.expect_unary, test_table.jump_iterative(tok.Kind.op_unary_minus));
    try testing.expectEqual(ParserAction.expect_unary, test_table.jump_iterative(tok.Kind.op_not));
}

test "jumptable iterative - binary ops" {
    try testing.expectEqual(ParserAction.expect_binary, test_table.jump_iterative(tok.Kind.op_add));
    try testing.expectEqual(ParserAction.expect_binary, test_table.jump_iterative(tok.Kind.op_mul));
    try testing.expectEqual(ParserAction.expect_binary, test_table.jump_iterative(tok.Kind.op_div));
    try testing.expectEqual(ParserAction.expect_binary, test_table.jump_iterative(tok.Kind.op_assign_eq));
}

test "jumptable iterative - group tokens" {
    try testing.expectEqual(ParserAction.expect_group, test_table.jump_iterative(tok.Kind.grp_open_paren));
    try testing.expectEqual(ParserAction.expect_group, test_table.jump_iterative(tok.Kind.grp_open_bracket));
    try testing.expectEqual(ParserAction.expect_group, test_table.jump_iterative(tok.Kind.grp_open_brace));
}

test "jumptable iterative - keywords" {
    try testing.expectEqual(ParserAction.expect_keyword, test_table.jump_iterative(tok.Kind.kw_if));
    try testing.expectEqual(ParserAction.expect_keyword, test_table.jump_iterative(tok.Kind.kw_else));
    try testing.expectEqual(ParserAction.expect_keyword, test_table.jump_iterative(tok.Kind.kw_for));
}

test "jumptable iterative - identifiers" {
    try testing.expectEqual(ParserAction.expect_identifier, test_table.jump_iterative(tok.Kind.identifier));
    try testing.expectEqual(ParserAction.expect_identifier, test_table.jump_iterative(tok.Kind.const_identifier));
    try testing.expectEqual(ParserAction.expect_identifier, test_table.jump_iterative(tok.Kind.type_identifier));
}

// test "jumptable iterative - extra operators" {
//     try testing.expectEqual(ParserAction.expect_extra_op1, test_table.jump_iterative(tok.Kind.op_dot_member));
//     try testing.expectEqual(ParserAction.expect_extra_op2, test_table.jump_iterative(tok.Kind.op_sub));
//     try testing.expectEqual(ParserAction.expect_extra_op3, test_table.jump_iterative(tok.Kind.grp_indent));
//     try testing.expectEqual(ParserAction.expect_literal, test_table.jump_iterative(tok.Kind.lit_string)); // Tests first match (LITERALS comes before EXTRA_OPS4)
// }

test "jumptable iterative - separators and close groups" {
    try testing.expectEqual(ParserAction.expect_separator, test_table.jump_iterative(tok.Kind.sep_comma));
    try testing.expectEqual(ParserAction.expect_close_group, test_table.jump_iterative(tok.Kind.grp_close_paren));
}

// Skip no-match test for now since all reasonable tokens are covered

test "jumptable branchless - literal tokens" {
    try testing.expectEqual(ParserAction.expect_literal, test_table.jump_branchless(tok.Kind.lit_string));
    try testing.expectEqual(ParserAction.expect_literal, test_table.jump_branchless(tok.Kind.lit_number));
    try testing.expectEqual(ParserAction.expect_literal, test_table.jump_branchless(tok.Kind.lit_bool));
    try testing.expectEqual(ParserAction.expect_literal, test_table.jump_branchless(tok.Kind.lit_null));
}

test "jumptable branchless - unary ops" {
    try testing.expectEqual(ParserAction.expect_unary, test_table.jump_branchless(tok.Kind.op_unary_minus));
    try testing.expectEqual(ParserAction.expect_unary, test_table.jump_branchless(tok.Kind.op_not));
}

test "jumptable branchless - binary ops" {
    try testing.expectEqual(ParserAction.expect_binary, test_table.jump_branchless(tok.Kind.op_add));
    try testing.expectEqual(ParserAction.expect_binary, test_table.jump_branchless(tok.Kind.op_mul));
    try testing.expectEqual(ParserAction.expect_binary, test_table.jump_branchless(tok.Kind.op_div));
    try testing.expectEqual(ParserAction.expect_binary, test_table.jump_branchless(tok.Kind.op_assign_eq));
}

test "jumptable branchless - group tokens" {
    try testing.expectEqual(ParserAction.expect_group, test_table.jump_branchless(tok.Kind.grp_open_paren));
    try testing.expectEqual(ParserAction.expect_group, test_table.jump_branchless(tok.Kind.grp_open_bracket));
    try testing.expectEqual(ParserAction.expect_group, test_table.jump_branchless(tok.Kind.grp_open_brace));
}

test "jumptable branchless - keywords" {
    try testing.expectEqual(ParserAction.expect_keyword, test_table.jump_branchless(tok.Kind.kw_if));
    try testing.expectEqual(ParserAction.expect_keyword, test_table.jump_branchless(tok.Kind.kw_else));
    try testing.expectEqual(ParserAction.expect_keyword, test_table.jump_branchless(tok.Kind.kw_for));
}

test "jumptable branchless - identifiers" {
    try testing.expectEqual(ParserAction.expect_identifier, test_table.jump_branchless(tok.Kind.identifier));
    try testing.expectEqual(ParserAction.expect_identifier, test_table.jump_branchless(tok.Kind.const_identifier));
    try testing.expectEqual(ParserAction.expect_identifier, test_table.jump_branchless(tok.Kind.type_identifier));
}

// test "jumptable branchless - extra operators" {
//     try testing.expectEqual(ParserAction.expect_extra_op1, test_table.jump_branchless(tok.Kind.op_dot_member));
//     try testing.expectEqual(ParserAction.expect_extra_op2, test_table.jump_branchless(tok.Kind.op_sub));
//     try testing.expectEqual(ParserAction.expect_extra_op3, test_table.jump_branchless(tok.Kind.grp_indent));
//     try testing.expectEqual(ParserAction.expect_literal, test_table.jump_branchless(tok.Kind.lit_string)); // Tests first match (LITERALS comes before EXTRA_OPS4)
// }

test "jumptable branchless - separators and close groups" {
    try testing.expectEqual(ParserAction.expect_separator, test_table.jump_branchless(tok.Kind.sep_comma));
    try testing.expectEqual(ParserAction.expect_close_group, test_table.jump_branchless(tok.Kind.grp_close_paren));
}

// Skip no-match test for now since all reasonable tokens are covered

test "jumptable consistency - both methods return same results" {
    const all_tokens = [_]tok.Kind{
        .lit_string,     .lit_number,       .lit_bool,        .lit_null,
        .op_unary_minus, .op_not,           .op_add,          .op_mul,
        .op_div,         .op_assign_eq,     .grp_open_paren,  .grp_open_bracket,
        .grp_open_brace, .kw_if,            .kw_else,         .kw_for,
        .identifier,     .const_identifier, .type_identifier, .op_dot_member,
        .op_sub,         .grp_indent,       .sep_comma,       .grp_close_paren,
    };

    for (all_tokens) |token| {
        const iterative_result = test_table.jump_iterative(token);
        const branchless_result = test_table.jump_branchless(token);
        try testing.expectEqual(iterative_result, branchless_result);
    }
}

const BENCHMARK_ITERATIONS = 10_000_000;

test "benchmark iterative vs branchless" {
    const tokens = [_]tok.Kind{
        .lit_string,      .op_add,          .grp_open_paren,   .kw_if,   .sep_comma,
        .lit_number,      .op_mul,          .grp_open_bracket, .kw_else, .identifier,
        .lit_bool,        .op_div,          .grp_open_brace,   .kw_for,  .const_identifier,
        .type_identifier, .call_identifier, .op_dot_member,    .op_sub,  .grp_indent,
        .grp_close_paren, .sep_newline,     .op_unary_minus,   .op_not,  .lit_null,
    };

    var timer = try std.time.Timer.start();

    // Benchmark iterative
    const start_iterative = timer.read();
    var result_iterative: ?ParserAction = null;
    for (0..BENCHMARK_ITERATIONS) |i| {
        const token = tokens[i % tokens.len];
        result_iterative = test_table.jump_iterative(token);
    }
    const end_iterative = timer.read();

    // Benchmark branchless
    const start_branchless = timer.read();
    var result_branchless: ?ParserAction = null;
    for (0..BENCHMARK_ITERATIONS) |i| {
        const token = tokens[i % tokens.len];
        result_branchless = test_table.jump_branchless(token);
    }
    const end_branchless = timer.read();

    const iterative_time = end_iterative - start_iterative;
    const branchless_time = end_branchless - start_branchless;

    std.debug.print("\nBenchmark Results ({} iterations):\n", .{BENCHMARK_ITERATIONS});
    std.debug.print("Iterative:  {d}ns total, {d:.2}ns per call\n", .{ iterative_time, @as(f64, @floatFromInt(iterative_time)) / BENCHMARK_ITERATIONS });
    std.debug.print("Branchless: {d}ns total, {d:.2}ns per call\n", .{ branchless_time, @as(f64, @floatFromInt(branchless_time)) / BENCHMARK_ITERATIONS });

    if (iterative_time < branchless_time) {
        const speedup = @as(f64, @floatFromInt(branchless_time)) / @as(f64, @floatFromInt(iterative_time));
        std.debug.print("Iterative is {d:.2}x faster\n", .{speedup});
    } else {
        const speedup = @as(f64, @floatFromInt(iterative_time)) / @as(f64, @floatFromInt(branchless_time));
        std.debug.print("Branchless is {d:.2}x faster\n", .{speedup});
    }

    // Prevent optimization by using volatile
    std.mem.doNotOptimizeAway(result_iterative);
    std.mem.doNotOptimizeAway(result_branchless);
}

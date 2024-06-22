const std = @import("std");
const mem = std.mem;
const asttypes = @import("ast.zig");

const Allocator = std.mem.Allocator;

const ParseOp = enum(u8) {
    uninitialized = 0, // Uninitialized state.
    fail = 1, // Terminate with an error.
    push = 2, // Push current char to context stack.
    pop = 3, // Emit the top of the current context stack.
    // Don't output or advance. Transition to next state and peek at current
    // context rather than input.
    peek = 4,
    advance = 5, // Advance the input, building up the current token.
    skip = 6, // Advance the input without emitting anything.
    emit = 7, // At an unambiguous terminal. Emit the current type onto the ast.

    // emit_op = 7, // At an unambiguous terminal. Emit the current type.
    // emit_num = 8, // Convert number to f64 value.
    // emit_str = 9, // Emit a reference to the string.
    // emit_ident = 10, // Get or create symbol entry for identifier.
    // emit_symbol = 11, // Get or create symbol, but tagged as a quoted symbol.
};

const TokenType = enum(u7) {
    uninitialized,
    number,
    string,
    ident,
    symbol,
    comment,

    // Other operations with special precedence.
    // Ordered by precedence for convenience (ones at top have higher precedence).
    open_brace,
    close_brace,
    open_paren,
    close_paren,
    open_bracket,
    close_bracket,

    member, // .

    // Prefix operations
    unary_inc,
    unary_dec,

    // Prefix - Mult-word. Can this be done in-language?
    is_not,
    not_in,
    op_not,

    op_pow,

    // Multiplication and division
    mul,
    div,
    mod,

    // Add/sub/unary plus/minus
    unary_plus,
    unary_minus,
    add,
    sub,

    // Comparisons
    lt,
    gt,
    lte,
    gte,

    op_is,
    op_in,
    op_as,
    is_eq,
    is_ne,

    // Logical
    op_and,
    op_or,

    kw_range, // ..

    op_union,

    assign,
    add_assign,
    sub_assign,
    mul_assign,
    div_assign,
    mod_assign,

    kw_colon,
    kw_comma,

    // Other keywords. Don't require any precedence.
    kw_if,
    kw_else,
    kw_elif,
    literal_true,
    literal_false,
    kw_def,
    tok_start_block,
    tok_continue_block,
    tok_end_block,
    kw_where,
    kw_then,

    call,
    index, // []
    array,
};

// For other constants, repeating the same char twice is an error.
const SENTINEL_END = []u8{0};
// const SENTINEL_DEFAULT = "__DEFAULT__";

// id, match, operation, next
const ParseSubState = struct {
    id: u32, // State ID. There will be multiple rows describing a single state.
    match: []const u8, // List of characters that match this sub-state
    operation: ParseOp, // Operation to perform on match.
    type: u7, // Match type to push/pop on the context stack.
    next: u32, // Next state to transition to after performing the operation.
};

const StateTransition = struct {
    operation: ParseOp = ParseOp.uninitialized,
    next: u32,
    type: u7 = 0,
};

pub const CompiledParseState = struct {
    /// Compiled state machine which consumes character, and outputs next-state.
    match: u128, // Bitset of ascii charcode -> match(1) or not(0)
    // Bitset of popcnt-index of char -> 0 (default next) or 1 (special cases)
    matchIndexNext: u64, 
    // The most common next-state shared by many characters.
    defaultNext: StateTransition, 
    // The other possible next-states. Indexed by popcnt-index. Index into an
    // array of StateTransitions defined in parent.
    nextOffset: usize, 
    fail: StateTransition, // What to do if the match failed.
};

const Token = struct {
    // todo: unaligned.
    type: u7,
    start: u32,
    end: u32,
};

fn cmpByState(_context: void, a: StateTransition, b: StateTransition) bool {
    _ = _context; // autofix
    return a.next < b.next or 
    @intFromEnum(a.operation) < @intFromEnum(b.operation) 
    or a.type < b.type;
}

pub fn mostFrequentTransition(currentState: [127]StateTransition) StateTransition {
    var cloneState: [127]StateTransition = mem.zeroes([127]StateTransition);
    // try mem.copyForwards(StateTransition, cloneState, currentState);
    for (currentState, 0..) |transition, i| {
        cloneState[i] = transition;
    }

    std.sort.heap(StateTransition, &cloneState, {},
     cmpByState);
    var mostFrequent = StateTransition{ 
        .operation = ParseOp.fail, 
        .next = 9999999, .type = 0 };
    var mostFrequentCount: u32 = 0;
    var currentCount: u32 = 0;
    var currentTransition = cloneState[0];
    for (currentState) |transition| {
        if (transition.operation != ParseOp.uninitialized and
         transition.next == currentTransition.next and
          transition.operation == currentTransition.operation and
           transition.type == currentTransition.type) {
            currentCount += 1;
        } else {
            if (currentCount > mostFrequentCount) {
                mostFrequent = currentTransition;
                mostFrequentCount = currentCount;
            }
            currentTransition = transition;
            currentCount = 1;
        }
    }
    return mostFrequent;
}

pub const TableParser = struct {
    const Self = @This();
    states: []const ParseSubState,
    compiled: std.ArrayList(CompiledParseState),
    transitions: std.ArrayList(StateTransition),
    allocator: Allocator,
    strings: std.StringHashMap(usize),
    symbols: std.StringHashMap(u64),
    ast: std.MultiArrayList(asttypes.AstNode),

    pub fn init(states: []const ParseSubState, allocator: Allocator) Self {
        const compiled = std.ArrayList(CompiledParseState).init(allocator);
        const transitions = std.ArrayList(StateTransition).init(allocator);
        const strings = std.StringHashMap(usize).init(allocator);
        const symbols = std.StringHashMap(u64).init(allocator);
        const ast = std.MultiArrayList(asttypes.AstNode).init(allocator);
        return Self{ .states = states, .allocator = allocator, 
        .compiled = compiled, .transitions = transitions, 
        .strings = strings, .symbols = symbols, .ast = ast };
    }

    pub fn deinit(self: *Self) void {
        self.compiled.deinit();
        self.transitions.deinit();
        self.strings.deinit();
        self.symbols.deinit();
        self.ast.deinit(self.allocator);
    }

    // Unhandled edge-cases
    // - No state has more than 64 matching states (bitset overflow).
    // - No more than 128 context 'type' values that can go on the stack.
    // - Max text length is 2^32 chars.
    // - The state table doesn't skip any state IDs and is in order.
    // - No patterns that depend on null character.
    // - Text can support unicode, as long as reserved keywords are still ascii.

    // pub fn charsetToMask(currentState: [128]StateTransition) u128 {
    //     var match: u128 = 0;
    //
    //     for(currentState.items(), 0..) |transition, i| {
    //         // TODO: Should fail be handled here or separate?
    //         if(transition.next == undefined or transition.operation == ParseOp.fail) {
    //             const mask: u128 = 1 << i;
    //             match |= mask;
    //         }
    //     }
    // }

    pub fn compileState(self: *Self, currentState: [127]StateTransition) !CompiledParseState {
        // Transform the array into a compact format.
        const defaultNext = mostFrequentTransition(currentState);
        const nextOffset = self.transitions.items.len;
        // const match = charsetToMask(currentState);

        var bitsetMatch: u128 = 0;
        var matchIndexNext: u64 = 0;
        var matchIndex: u6 = 0;

        var i: u7 = 0;

        for (currentState) |transition| {
            // print("Transition: {d} - {d}\n", .{ i, transition.next });
            // TODO: Should fail be handled here or separate?
            if (transition.operation != ParseOp.uninitialized) {
                const mask: u128 = @as(u128, 1) << i;
                // print("Index {d} Mask:  {b}\n", .{ i, mask });
                bitsetMatch |= mask;
                // print("Bitset match: {b}\n", .{bitsetMatch});

                if (transition.next != defaultNext.next or 
                transition.operation != defaultNext.operation or 
                transition.type != defaultNext.type) {
                    // Defaults are set to 0. Everything else is a 1.
                    const matchMask: u64 = @as(u64, 1) << matchIndex;
                    matchIndexNext |= matchMask;
                    try self.transitions.append(transition);
                }
                matchIndex += 1;
            }
            i += 1;
        }

        return CompiledParseState{
            .match = bitsetMatch,
            .matchIndexNext = matchIndexNext,
            .defaultNext = defaultNext,
            .nextOffset = nextOffset,
            .fail = StateTransition{ .operation = ParseOp.fail, .next = 0, .type = 0 },
        };
    }

    pub fn compile(self: *Self) !void {
        var currentState = mem.zeroes([127]StateTransition);

        var currentId: usize = 0;
        // Convert the state table to a compiled parse state table which is more efficient for lookup.
        for (self.states) |state| {
            if (state.id != currentId) {
                const compiledState = try self.compileState(currentState);
                try self.compiled.append(compiledState);
                currentState = mem.zeroes([127]StateTransition);
                currentId = state.id;
            }

            for (state.match) |char| {
                if (currentState[char].operation == ParseOp.uninitialized) {
                    // print("Setting {d} for char {c}\n", .{ currentId, char });
                    currentState[char] = StateTransition{ .operation = state.operation, 
                    .next = state.next, .type = state.type };
                } else {
                    // Can't have two rules defining conflicting matches for the same character.
                    print("Duplicate character match definition: {c} for state {d}.", .{ char, state.id });
                }
            }
        }

        // Flush the final state.
        const compiledState = try self.compileState(currentState);
        try self.compiled.append(compiledState);
    }

    pub fn match(self: *Self, input: []const u8) void {
        var currentState = self.compiled.items[0];

        // TODO: These are vars
        const matchContext = false;
        const context = std.ArrayList(u7).init(self.allocator);

        // TODO: Context stack
        // TODO: Variable to track whether we're matching input string or context stack.

        var i: usize = 0;
        while (i < input.len) {
            print("Matching character: {c}\n", .{input[i]});
            if (input[i] > 128) {
                print("Non-ascii character: {c}\n", .{input[i]});
                break;
            }
            const char: u7 = @truncate(input[i]);

            // Could avoid this branch by setting the right value based on the operation in the previous step at end of loop.
            var matchChar = char;
            if (matchContext) {
                if (context.items.len > 0) {
                    matchChar = context.items[context.items.len - 1];
                } else {
                    print("No context to match against.\n", .{});
                }
            }

            // const state = self.compiled[currentState.next];
            // TODO: Non-ascii

            const charMask: u127 = @as(u127, 1) << char;
            print("Expecting {b}\n", .{currentState.match});
            // Check if the bit is set at the character's index, indicating a match.
            if ((currentState.match & charMask) != 0) {
                // Specify a mask with the first N bits set to 1, so we can compute how many characters < C matches.
                const charMatchIndexMask = charMask - 1; // N bits set to 1.
                // Count how many chars can match < current char.
                const matchIndex: u6 = @truncate(
                    @popCount(charMatchIndexMask & currentState.match));
                // Assert - matchIndexCount < 64

                print("Non-default match: {b}\n", .{currentState.matchIndexNext});

                // Use that index to lookup in a bitset of whether it's the most common default match
                const defaultNextMask: u64 = @as(u64, 1) << matchIndex;
                const isDefaultNextState = (currentState.matchIndexNext & 
                defaultNextMask) == 0;
                // The most common transition is stored in a separate field to reduce duplication in the nextState array.
                var nextTransition: StateTransition = currentState.defaultNext;
                if (!isDefaultNextState) {
                    // Otherwise, lookup by the non-zero'th index to find the
                    // distinct next state.
                    const nextIndexMask = defaultNextMask - 1;
                    const nextIndex = @popCount(
                        currentState.matchIndexNext & nextIndexMask);

                    nextTransition = self.transitions.items[
                        currentState.nextOffset + nextIndex];
                }
                print("Match. Next state: {d}. Op {?}\n", .{ 
                    nextTransition.next, nextTransition.operation });

                currentState = self.compiled.items[nextTransition.next];

                // TODO: Do the operation.

            } else {
                print("No match for character: {c}\n", .{char});
                // No match.
                // currentState = currentState.fail;
                return;
            }

            // TODO: Do this only if we're advancing the input
            i += 1;
        }
        // return currentToken;
        print("All Matches", .{});
    }
};

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const print = std.debug.print;

const TBL_FLOAT = [_]ParseSubState{
    ParseSubState{ .id = 0, .match = "0123456789", 
    .operation = ParseOp.advance, .next = 1, .type = 0 },
    ParseSubState{ .id = 0, .match = ".", 
    .operation = ParseOp.advance, .next = 2, .type = 0 },
    // ParseSubState{ .id = 0, .match = SENTINEL_END, .operation = ParseOp.fail, .next = 0 },  // Empty string.
    ParseSubState{ .id = 1, .match = "0123456789", 
    .operation = ParseOp.advance, .next = 1, .type = 0 },
    ParseSubState{ .id = 1, .match = ".", 
    .operation = ParseOp.advance, .next = 2, .type = 0 },
    // TODO ParseSubState{ .id = 1, .match = SENTINEL_END, .operation = ParseOp.emit, .next = 0, .type = 0 },
    ParseSubState{ .id = 2, .match = "0123456789", 
    .operation = ParseOp.advance, .next = 3, .type = 0 },
    // ParseSubState{ .id = 2, .match = SENTINEL_END, .operation = ParseOp.fail, .next = 0 },  // . without fractions.
    ParseSubState{ .id = 3, .match = "0123456789", 
    .operation = ParseOp.advance, .next = 3, .type = 0 }, // Parse fractions.
    // TODO ParseSubState{ .id = 3, .match = SENTINEL_END, .operation = ParseOp.emit, .next = 0, .type = 0 },
};

test "Float parser" {
    // Simplified float parser. No support for e.
    const tbl = TBL_FLOAT;
    const parser = TableParser.init(&tbl, test_allocator);
    // try expect(parser.states.len == 8);
    try expect(parser.states.len == 6);
}

test "Most frequent state transition" {
    var states = mem.zeroes([127]StateTransition);

    states[0] = StateTransition{ .operation = ParseOp.advance, .next = 0, 
    .type = 0 };
    states[1] = StateTransition{ .operation = ParseOp.advance, .next = 0, .type = 0 };
    states[2] = StateTransition{ .operation = ParseOp.advance, .next = 1, .type = 0 };
    states[3] = StateTransition{ .operation = ParseOp.advance, .next = 1, .type = 0 };
    states[4] = StateTransition{ .operation = ParseOp.advance, .next = 1, .type = 0 };
    states[5] = StateTransition{ .operation = ParseOp.advance, .next = 3, .type = 1 };
    states[6] = StateTransition{ .operation = ParseOp.advance, .next = 3, .type = 2 };
    states[7] = StateTransition{ .operation = ParseOp.advance, .next = 3, .type = 3 };
    states[7] = StateTransition{ .operation = ParseOp.advance, .next = 3, .type = 3 };

    const mostFrequent = mostFrequentTransition(states);
    try expect(mostFrequent.next == 1);
}

test "Compile state" {
    var states = mem.zeroes([127]StateTransition);

    states[0] = StateTransition{ .operation = ParseOp.advance, .next = 0, 
    .type = 0 };
    states[2] = StateTransition{ .operation = ParseOp.advance, .next = 0, 
    .type = 0 };
    states[3] = StateTransition{ .operation = ParseOp.advance, .next = 1, 
    .type = 0 };
    states[5] = StateTransition{ .operation = ParseOp.advance, .next = 1, 
    .type = 0 };
    states[6] = StateTransition{ .operation = ParseOp.advance, .next = 1, 
    .type = 0 };
    states[7] = StateTransition{ .operation = ParseOp.advance, .next = 3, 
    .type = 1 };
    states[10] = StateTransition{ .operation = ParseOp.advance, .next = 3, 
    .type = 2 };
    states[11] = StateTransition{ .operation = ParseOp.advance, .next = 3, 
    .type = 3 };

    const tbl = [_]ParseSubState{};
    var parser = TableParser.init(&tbl, test_allocator);
    defer parser.deinit();
    const compiled = try parser.compileState(states);
    print("Compiled: {b} \n", .{compiled.match});
    try expect(compiled.match == 0b110011101101);
    // Most common = next 1.
    // try expect(compiled.matchIndexNext == 0b1110000);
    try expect(compiled.matchIndexNext == 0b11100011);
    try expect(compiled.defaultNext.next == 1);
    try expect(compiled.defaultNext.operation == ParseOp.advance);
    try expect(compiled.defaultNext.type == 0);
    try expect(parser.transitions.items.len == 5);
}

test "Match float" {
    const tbl = TBL_FLOAT;
    var parser = TableParser.init(&tbl, test_allocator);
    defer parser.deinit();
    try parser.compile();
    parser.match("123.45k6");
}

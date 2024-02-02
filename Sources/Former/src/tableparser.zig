const std = @import("std");
const mem = std.mem;

const Allocator = std.mem.Allocator;

const ParseOp = enum(u8) {
    uninitialized = 0, // Uninitialized state.
    push = 1, // Push current char to context stack.
    pop = 2, // Emit the top of the current context stack.
    fail = 3, // Terminate with an error.
    emit = 4, // At an unambiguous terminal. Emit the current type.
    advance = 5, // Advance the input, building up the current token.
    skip = 6, // Advance the input without emitting anything.
    peek = 7, // Don't output or advance. Transition to next state and peek at current context rather than input.
};

// For other constants, repeating the same char twice is an error.
const SENTINEL_END = "__END__";
const SENTINEL_DEFAULT = "__DEFAULT__";

// id, match, operation, next
const ParseSubState = struct {
    id: u32, // State ID. There will be multiple rows describing a single state.
    match: []const u8, // List of characters that match this sub-state
    operation: ParseOp, // Operation to perform on match.
    type: u8, // Match type to push/pop on the context stack.
    next: u32, // Next state to transition to after performing the operation.
};

const StateTransition = struct {
    operation: ParseOp = ParseOp.uninitialized,
    next: u32,
    type: u8 = 0,
};

pub const CompiledParseState = struct {
    /// Compiled state machine which consumes character, and outputs next-state.
    match: u128, // Bitset of ascii charcode -> match(1) or not(0)
    matchIndexNext: u64, // Bitset of popcnt-index of char -> 0 (default next) or 1 (special cases)
    defaultNext: StateTransition, // The most common next-state shared by many characters.
    nextOffset: usize, // The other possible next-states. Indexed by popcnt-index. Index into an array of StateTransitions defined in parent.
    fail: StateTransition, // What to do if the match failed.
};

const Token = struct {
    // todo: unaligned.
    type: u8,
    start: u32,
    end: u32,
};

fn cmpByState(_context: void, a: StateTransition, b: StateTransition) bool {
    _ = _context; // autofix
    return a.next < b.next or @intFromEnum(a.operation) < @intFromEnum(b.operation) or a.type < b.type;
}

pub fn mostFrequentTransition(currentState: [127]StateTransition) StateTransition {
    var cloneState: [127]StateTransition = mem.zeroes([127]StateTransition);
    // try mem.copyForwards(StateTransition, cloneState, currentState);
    for (currentState, 0..) |transition, i| {
        cloneState[i] = transition;
    }

    std.sort.heap(StateTransition, &cloneState, {}, cmpByState);
    var mostFrequent = StateTransition{ .operation = ParseOp.fail, .next = 9999999, .type = 0 };
    var mostFrequentCount: u32 = 0;
    var currentCount: u32 = 0;
    var currentTransition = cloneState[0];
    for (currentState) |transition| {
        if (transition.operation != ParseOp.uninitialized and transition.next == currentTransition.next and transition.operation == currentTransition.operation and transition.type == currentTransition.type) {
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

    pub fn init(states: []const ParseSubState, allocator: Allocator) Self {
        return Self{ .states = states, .allocator = allocator, .compiled = std.ArrayList(CompiledParseState).init(allocator), .transitions = std.ArrayList(StateTransition).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.compiled.deinit();
        self.transitions.deinit();
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
            print("Transition: {d} - {d}\n", .{ i, transition.next });
            // TODO: Should fail be handled here or separate?
            if (transition.operation != ParseOp.uninitialized) {
                const mask: u128 = @as(u128, 1) << i;
                print("Index {d} Mask:  {b}\n", .{ i, mask });
                bitsetMatch |= mask;
                print("Bitset match: {b}\n", .{bitsetMatch});

                if (transition.next != defaultNext.next or transition.operation != defaultNext.operation or transition.type != defaultNext.type) {
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
        var currentState = mem.defaultsOrUndefined([127]StateTransition);

        var currentId = 0;
        // Convert the state table to a compiled parse state table which is more efficient for lookup.
        for (self.states.items()) |state| {
            if (state.id == currentId) {
                for (state.match.items()) |char| {
                    if (currentState[char].next == undefined) {
                        currentState[char] = StateTransition{ .operation = state.operation, .next = state.next, .type = state.type };
                    } else {
                        // Can't have two rules defining conflicting matches for the same character.
                        print("Duplicate character match definition: {s} for state {d}.", .{ char, state.id });
                    }
                }
            } else {
                self.compiled[currentId] = compileState(currentState);
                currentState = mem.defaultsOrUndefined([127]StateTransition);
                currentId = state.id;
            }
        }
    }

    pub fn match(self: *Self, input: []const u8) void {
        var currentState = self.compiled[0];

        // TODO: These are vars
        const matchContext = true;
        const context = std.ArrayList(u8).init(self.allocator);
        // TODO: Context stack
        // TODO: Variable to track whether we're matching input string or context stack.

        var i = 0;
        while (i < input.len) {
            const char = input[i];

            // Could avoid this branch by setting the right value based on the operation in the previous step at end of loop.
            var matchChar = char;
            if (matchContext) {
                if (context.len > 0) {
                    matchChar = context[context.len - 1];
                } else {
                    print("No context to match against.", .{});
                }
            }

            const state = self.compiled[currentState.next];
            // TODO: Non-ascii
            const charMask: u128 = 1 << char;
            // Check if the bit is set at the character's index, indicating a match.
            if ((state.match & charMask) != 0) {
                // Specify a mask with the first N bits set to 1, so we can compute how many characters < C matches.
                const charMatchIndexMask = charMask - 1; // N bits set to 1.
                // Count how many chars can match < current char.
                const matchIndex = @popCount(charMatchIndexMask & state.match);
                // Use that index to lookup in a bitset of whether it's the most common default match
                const defaultNextMask: u64 = 1 << matchIndex;
                const isDefaultNextState = (state.matchIndexNext & defaultNextMask) == 0;
                if (isDefaultNextState) {
                    // Re-use a single variable for the most common match.
                    currentState = state.defaultNext;
                } else {
                    // Otherwise, lookup by the non-zero'th index to find the distinct next state.
                    const nextIndexMask = defaultNextMask - 1;
                    const nextIndex = @popCount(state.matchIndexNext & nextIndexMask);

                    const nextTransition = state.next[nextIndex];
                    currentState = nextTransition;
                }
                print("Match. Next state: {d}. Op {x}", .{ currentState.next, currentState.operation });

                // TODO: Do the operation.

            } else {
                print("No match for character: {c}", .{char});
                // No match.
                currentState = state.fail;
            }

            // TODO: Do this only if we're advancing the input
            i += 1;
        }
        // return currentToken;
        print("Matches", .{});
    }
};

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const print = std.debug.print;

test "Float parser" {
    // Simplified float parser. No support for e.
    const tbl = [_]ParseSubState{
        ParseSubState{ .id = 0, .match = "0123456789", .operation = ParseOp.advance, .next = 1, .type = 0 },
        ParseSubState{ .id = 0, .match = ".", .operation = ParseOp.advance, .next = 2, .type = 0 },
        // ParseSubState{ .id = 0, .match = SENTINEL_END, .operation = ParseOp.fail, .next = 0 },  // Empty string.
        ParseSubState{ .id = 1, .match = "0123456789", .operation = ParseOp.advance, .next = 1, .type = 0 },
        ParseSubState{ .id = 1, .match = ".", .operation = ParseOp.advance, .next = 2, .type = 0 },
        ParseSubState{ .id = 1, .match = SENTINEL_END, .operation = ParseOp.emit, .next = 0, .type = 0 },
        ParseSubState{ .id = 2, .match = "0123456789", .operation = ParseOp.advance, .next = 3, .type = 0 },
        // ParseSubState{ .id = 2, .match = SENTINEL_END, .operation = ParseOp.fail, .next = 0 },  // . without fractions.
        ParseSubState{ .id = 3, .match = "0123456789", .operation = ParseOp.advance, .next = 3, .type = 0 }, // Parse fractions.
        ParseSubState{ .id = 3, .match = SENTINEL_END, .operation = ParseOp.emit, .next = 0, .type = 0 },
    };
    const parser = TableParser.init(&tbl, test_allocator);
    try expect(parser.states.len == 8);
}

test "Most frequent state transition" {
    var states = mem.zeroes([127]StateTransition);

    states[0] = StateTransition{ .operation = ParseOp.advance, .next = 0, .type = 0 };
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

    states[0] = StateTransition{ .operation = ParseOp.advance, .next = 0, .type = 0 };
    states[2] = StateTransition{ .operation = ParseOp.advance, .next = 0, .type = 0 };
    states[3] = StateTransition{ .operation = ParseOp.advance, .next = 1, .type = 0 };
    states[5] = StateTransition{ .operation = ParseOp.advance, .next = 1, .type = 0 };
    states[6] = StateTransition{ .operation = ParseOp.advance, .next = 1, .type = 0 };
    states[7] = StateTransition{ .operation = ParseOp.advance, .next = 3, .type = 1 };
    states[10] = StateTransition{ .operation = ParseOp.advance, .next = 3, .type = 2 };
    states[11] = StateTransition{ .operation = ParseOp.advance, .next = 3, .type = 3 };

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

// id, match, operation, next
// const CSV_PARSER = [];

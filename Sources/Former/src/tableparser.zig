const std = @import("std");

const Allocator = std.mem.Allocator;


const ParseOp = enum {
    push,  // Push current char to context stack.
    pop,   // Emit the top of the current context stack.
    fail,   // Terminate with an error.
    emit,   // At an unambiguous terminal. Emit the current type.
    advance, // Advance the input, building up the current token.
    skip,   // Advance the input without emitting anything.
    peek    // Don't output or advance. Transition to next state and peek at current context rather than input.
};

// For other constants, repeating the same char twice is an error.
const SENTINEL_END = "__END__";
const SENTINEL_DEFAULT = "__DEFAULT__";


// id, match, operation, next
const ParseSubState = struct {
    id: u32,    // State ID. There will be multiple rows describing a single state.
    match: []const u8,   // List of characters that match this sub-state
    operation: ParseOp, // Operation to perform on match.
    next: u32   // Next state to transition to after performing the operation.
};

const StateTransition = struct {
    operation: ParseOp,
    next: u32,
    type: u8              //
};

const CompiledParseState = struct {
    /// Compiled state machine which consumes character, and outputs next-state.
    match: u128,  // Bitset of ascii charcode -> match(1) or not(0)
    matchIndexNext: u64, // Bitset of popcnt-index of char -> 0 (default next) or 1 (special cases)
    defaultNext: StateTransition, // The most common next-state shared by many characters.
    next: *[u8]StateTransition, // The other possible next-states. Indexed by popcnt-index.
    fail: StateTransition, // What to do if the match failed.
};

const Token = struct {
    // todo: unaligned.
    type: u8,
    start: u32,
    end: u32,
};


pub const TableParser = struct {
    const Self = @This();
    states: []const ParseSubState,
    //compiled: []const CompiledParseState,

    allocator: Allocator,

    pub fn init(states: []const ParseSubState, allocator: Allocator) Self {
        return Self { .states = states, .allocator = allocator };
    }

    // Unhandled edge-cases
    // - No state has more than 64 matching states (bitset overflow).
    // - No more than 128 context 'type' values that can go on the stack.
    // - Max text length is 2^32 chars.
    // - The state table doesn't skip any state IDs and is in order.
    // - No patterns that depend on null character.
    // - Text can support unicode, as long as reserved keywords are still ascii.

    // pub fn compile(self: *Self) !void {
    // // Convert the state table to a compiled parse state table which is more efficient for lookup.
    // }

};


const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const print = std.debug.print;

test "Float parser" {
    // Simplified float parser. No support for e.
    const tbl = [_]ParseSubState{
        ParseSubState{ .id = 0, .match = "0123456789", .operation = ParseOp.advance, .next = 1 },
        ParseSubState{ .id = 0, .match = ".", .operation = ParseOp.advance, .next = 2 },
        // ParseSubState{ .id = 0, .match = SENTINEL_END, .operation = ParseOp.fail, .next = 0 },  // Empty string.
        ParseSubState{ .id = 1, .match = "0123456789", .operation = ParseOp.advance, .next = 1 },
        ParseSubState{ .id = 1, .match = ".", .operation = ParseOp.advance, .next = 2 },
        ParseSubState{ .id = 1, .match = SENTINEL_END, .operation = ParseOp.emit, .next = 0 },
        ParseSubState{ .id = 2, .match = "0123456789", .operation = ParseOp.advance, .next = 3 },
        // ParseSubState{ .id = 2, .match = SENTINEL_END, .operation = ParseOp.fail, .next = 0 },  // . without fractions.
        ParseSubState{ .id = 3, .match = "0123456789", .operation = ParseOp.advance, .next = 3 }, // Parse fractions.
        ParseSubState{ .id = 3, .match = SENTINEL_END, .operation = ParseOp.emit, .next = 0 },
    };
    const parser = TableParser.init(tbl, test_allocator);
    expect(parser.states.len == 10);
}



// id, match, operation, next
// const CSV_PARSER = [];
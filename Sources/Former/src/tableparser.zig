

const ParseOp = enum {
    push,
    pop,
    output,
    fail,
    skip,
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
    next: u32
};

const CompiledParseState = struct {
    /// Compiled state machine which consumes character, and outputs next-state.
    match: u128,  // Bitset of ascii charcode -> match(1) or not(0)
    matchIndexNext: u64, // Bitset of popcnt-index of char -> 0 (default next) or 1 (special cases)
    defaultNext: StateTransition, // The most common next-state shared by many characters.
    next: *[u8]StateTransition, // The other possible next-states. Indexed by popcnt-index.
    fail: StateTransition, // What to do if the match failed.
};


// id, match, operation, next
// const CSV_PARSER = [];
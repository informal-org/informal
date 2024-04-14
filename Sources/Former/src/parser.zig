const std = @import("std");
const val = @import("value.zig");
const tok = @import("token.zig");
const constants = @import("constants.zig");
const q = @import("queue.zig");
const bitset = @import("bitset.zig");

const print = std.debug.print;
const Token = tok.Token;
const TokenQueue = q.Queue(Token);
const OffsetQueue = q.Queue(u16);
const Allocator = std.mem.Allocator;

const TokBitset = bitset.BitSet64;



// The parser takes a token stream from the lexer and converts it into a valid structure.
// It's only concerned with the grammatic structure of the code - not the meaning.
// It's a hybrid state-machine / recursive descent parser with state tables.
pub const Parser = struct {
    const Self = @This();
    buffer: []const u8,
    syntaxQ: *TokenQueue,
    auxQ: *TokenQueue,

    // The AST is stored is a postfix order - where all operands come before the operator.
    // This stack structure avoids the need for any explicit pointers for operators
    // and matches the dependency order we want to emit bytecode in and matches the order of evaluation.
    parsedQ: *TokenQueue, 
    // For each token in the parsedQ, indicates where to find it in the syntaxQ.
    offsetQ: *OffsetQueue,
    opStack: std.MultiArrayList(ParseNode),

    allocator: Allocator,
    index: u32,

    pub fn init(buffer: []const u8, syntaxQ: *TokenQueue, auxQ: *TokenQueue,  allocator: Allocator) Self {
        const opStack = std.MultiArrayList(ParseNode).init(allocator);
        
        return Self{.buffer = buffer, .syntaxQ = syntaxQ, .auxQ = auxQ, .allocator = allocator, .index = 0, .opStack = opStack};    
    }

    pub fn deinit(self: *Self) void {
        self.opStack.deinit();
    }

    
    /////////////////////////////////////////////
    // Initial State
    // Null state at the beginning of the file;
    // Valid states:
    // Literals - Emit directly. Transition to expect_binary
    // Identifiers - Emit directly. Transition to expect after identifier.
    // ( - Push onto the stack. Transition to initial_state.
    // Block keywords like def, if, etc. are valid. Switch to their custom handlers.
    // ------------------------------------------
    // Invalid states:
    // Binary operators - need an operand on the left.
    // { } - Empty scope is invalid?
    // Indent - Indentation at beginning of file is invalid.
    // Separators - , ; etch are invalid at the beginning.
    /////////////////////////////////////////////
    
    
    /////////////////////////////////////////////
    /// Expect Binary Literal Operations
    /// We've seen an operand on the left. Now expecting a binary operation.
    /// Valid states:
    /// Binary operators:
    ///     Precedence flush: Lookup current operator for a bitmask of what to flush - encodes precedence and associtivity.
    ///     Check any non-matches if they're error-cases in another bitset.
    ///     Push the operand onto the stack - indicate that it's a binary op (to differentiate unary vs binary -)
    ///     Transition to expect_unary.
    /// Separators - 1, 2
    /// Invalid States:
    /// Literals / Identifiers - Need a binary operator. 1 1 is invalid.
    /// Unary operators. ex. True not.
    /// Grouping operators. ex. 1 (... 
    /////////////////////////////////////////////
    

    /////////////////////////////////////////////
    /// Expect Identifier Operations
    /// We've seen an identifier to the left. You can do an operation on it.
    /// Or it might be a function call foo()
    /// Or an index access. foo[0]
    /// Or a declaration like class foo {} (TODO: Needs more thought...)
    /// Separators - a, b = 1, 2
    /// Invalid states:
    /// Other identifiers or literals.
    /// Unary operators.
    

    /////////////////////////////////////////////
    /// Expect Binary String Operations
    /// We've seen a string literal. You can index it, or call string functions on it.
    /// Allow [] and . operations and other binary functions like +, and, etc.
    /////////////////////////////////////////////
    

    /////////////////////////////////////////////
    /// Expect Right Unary Operations. a op ___
    /// We're in the middle of an expression. There may be an operator to the left.
    /// Valid states:
    /// Unary operators:
    ///     Precedence flush.
    /// Literals: 
    ///     Numeric -> Expect binary literal operations.
    ///     String -> Expect binary string operations.
    /// Keyword starts - sub-expressions which will give a value. x + if y then z else w
    /// Identifiers: -> Expect identifier operations
    /// Grouping is valid. i.e. 1 * (2 + 3)
    /// Invalid states: 
    /// Binary operators.
    /// Indentation, separators, {}, [].
    /// Keyword continuations - i.e. a + else
    

    /////////////////////////////////////////////
    /// Expect assignment right. a = ___
    /// We're at an assignment operator.
    /// Mark the currently open line or group as containing an assignment.
    /// This allows the symbol-resolution to recognize declaration vs reference without lookahead.
    /// That'll also support de-structuring like [a, b, c] = ...
    /////////////////////////////////////////////
    
    

    // Initialize the parser state.
    // Note: All sub-parse functions MUST be tail-recursive, in a direct-threaded style.
    // Each state function should process a token at a time, with no lookahead or backtracking.
    // pub fn parse(self: *Self) void {

    // }


};

// Internal structure to keep track of operator's positions while the parser constructs the tree.
// Turns into the parsedQ and offsetQ when done.
const ParseNode = struct {
    token: Token,
    index: u32,
};

const ParseState = struct {
    match: TokBitset,
    // Next-state transitions. Index 0 contains the most common transition for all 0 bits.
    // Indexed by popcnt index for next-state.
    transition: []const StateTransition,
};


const StateTransition = struct {
    // 1 if this is a non-terminal. 0 for terminal.
    action: StateAction,
    next: u32,  // Index into the state table or the error table depending on action.

    const StateAction = enum {
        fail,   // Terminate with an error when reaching an unexpected state.
        push,   // Push the current token onto the context stack.
        pop,    // Emit the top of the current context stack.
        skip,   // Skip emitting the current token.
        emit,   // Emit the current token directly onto the output.
    };
};


const StateTable = struct { 

};



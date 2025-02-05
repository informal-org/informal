const std = @import("std");
const q = @import("queue.zig");
const tok = @import("token.zig");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Token = tok.Token;

pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);

pub const IrTokenKind = enum(u6) {
    // Register operations
    defvar, // Define a new variable as a result of an operation. Exists in a register.
    refvar, // Reference an existing variable or constant which may exist in a register or memory.
    refimm, // Specialize refvar for small immediate values.
    refreg, // Reference a variable in a register.
    load, // Load a variable from memory into a register.
    store, // Save register contents to memory.
    drop, // Mark a register as free - no need so save its contents.
};

pub const IR = struct {
    // The Intermediate Representation (IR) begins the mididdle-end of the compiler.
    // The frontend is language-specific, while the IR and subsequent layers should ideally be treated as largely language-agnostic.
    // Informal's IR is composed of tokens, with additional synthetic tokens to make expressions more explicit.
    // There's two queues, with the alternate bit switching between the data and effects queues.
    // The order remains the same, and filtering out the synthetic ops allow us to link to earlier layers by the token index.
    // It is closest to ANF, but has elements of SSA and CFG.

    const Self = @This();
    allocator: Allocator,
    parsedQ: *TokenQueue,
    dataQ: *TokenQueue, // Contains data and operations. Aux-bit to switch to effects queue. Essentially basic-block like operations.
    effectsQ: *TokenQueue, // Contains effects - control-flow, IO, observable state mutations, etc. Maintains soft-dependencies / ordering.

    pub fn init(allocator: Allocator, parsedQ: *TokenQueue, irQ: *TokenQueue, buffer: []const u8) Self {
        return Self{ .allocator = allocator, .parsedQ = parsedQ, .irQ = irQ, .buffer = buffer };
    }

    pub fn build(self: *Self) !void {
        // Build the IR Queue from the parsed queue.
        // Variable / constant definitions -> DEFVAR instructions.
        // Constants inline.
        // Variable references -> REFVAR instruction.
        // Operation:
        // - Argument references immediately precede it.
        // Code locations for branch / jumps become DEFLOC instructions.
        // Branch - REFVAR to reference the target locations.

        // Indicates if the current token is in the alternate queue instead.
        // Different pattern than what we use in the lexer where it indicated if the 'next' token is in the other queue
        // which required keeping the previous token and flushing it. This seems simpler.
        // TODO: Should refactor the lexer to this alternate convention if it works better.
        var alternate = false;
        // var prevToken

        for (self.parsedQ.list.items) |t| {
            // Clear the aux-bit from previous contexts.
            const token = Token{ .kind = t.kind, .data = t.data, .alternate = alternate };
            alternate = false;

            switch (token.kind) {
                tok.TK.kw_if, tok.TK.kw_else_if, tok.TK.kw_else => {
                    // Add control-flow constructs to a separate queue.
                    try self.controlQ.push(token);
                    alternate = true; // Set the alternate bit on the next
                },
                else => {
                    // Most things are data operations.
                    try self.dataQ.push(token);
                },
            }
        }
    }
};

test {
    @import("std").testing.refAllDecls(@This());
}

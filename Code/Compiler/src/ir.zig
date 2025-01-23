const std = @import("std");
const q = @import("queue.zig");
const tok = @import("token.zig");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Token = tok.Token;

pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);

pub const IR = struct {
    // The IR is composed of tokens, with additional synthetic tokens to make expressions more explicit.
    // There's two queues, with the alternate bit switching between the data and effects queues.
    // The order remains the same, and filtering out the synthetic ops allow us to link to earlier layers by the token index.
    // It is closest to ANF, but has elements of SSA and CFG.

    const Self = @This();
    allocator: Allocator,
    parsedQ: *TokenQueue,
    dataQ: *TokenQueue, // Contains data and operations. Aux-bit to switch to effects queue. Essentially basic-block like operations.
    effectsQ: *TokenQueue, // Contains effects - control-flow, IO, observable state mutations, etc. Maintains soft-dependencies / ordering.

    pub fn init(allocator: Allocator, parsedQ: *TokenQueue, irQ: *TokenQueue) Self {
        return Self{ .allocator = allocator, .parsedQ = parsedQ, .irQ = irQ };
    }

    pub fn build(_: *Self) !void {
        // Build the IR Queue from the parsed queue.
        // Variable / constant definitions -> DEFVAR instructions.
        // Constants inline.
        // Variable references -> REFVAR instruction.
        // Operation:
        // - Argument references immediately precede it.
        // Code locations for branch / jumps become DEFLOC instructions.
        // Branch - REFVAR to reference the target locations.

    }
};

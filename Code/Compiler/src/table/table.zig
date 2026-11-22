const std = @import("std");
const BitSet128 = @import("../bitset.zig").BitSet128;

pub const ENTRY_WIDTH_MASKS = [4]u8{ 0x01, 0x03, 0x0F, 0xFF };

pub const STREAM_END: u8 = 127;
pub const STREAM_START: u8 = 126;

pub const Table = struct {
    const Self = @This();

    pub const Op = enum(u5) {
        // Lexer ops
        none, // Do nothing
        emit, // Emit a token
        emit_aux,
        emit_int, // Parse selection as int.
        emit_end,
        emit_sym,
        // Parser ops
        err, // Terminate with error
        emit_val, // Emit current token.
        push_op, // Precedence shift.
        push_prefix_op,
        flush_all, // Flush remaining
    };

    pub const State = packed struct(u32) {
        transition_id: u16,
        width: u2, // 2^n wide transition table size. Really belongs with the transition table, but size works out better here.
        consume: bool, // Consume the symbol that led here, or false - dispatch on it again.
        op: Op, // Action on state activation.
        arg: u8, // Arg for op.
    };

    states: []const State,
    // 1<<width transition bitsets at transition_id offset, with the slot immediately after being the ID->u16 state ID map.
    transitions: []const u8,

    parserStartId: usize,

    auxStart: u8,

    pub const Slot = struct { byte: usize, shift: u3, mask: u8 };

    pub inline fn slot(width: u2, ch: u7) Slot {
        const bit = @as(usize, ch) << width;
        // Since width is 1, 2, 4, 8 it never crosses bytes.
        return .{
            .byte = bit >> 3, // div by 8
            .shift = @truncate(bit),
            .mask = ENTRY_WIDTH_MASKS[width],
        };
    }

    pub inline fn bitmapSize(width: u2) usize {
        return @as(usize, 16) << width;
    }

    pub fn targets(comptime self: Table, comptime state: State) []const u8 {
        const start = state.transition_id + bitmapSize(state.width);
        const len: usize = @min(ENTRY_WIDTH_MASKS[state.width], 127);
        return self.transitions[start .. start + len + 1];
    }

    pub fn nextStateId(self: Self, current: State, char: u7) u8 {
        const offset = slot(current.width, char);
        // Read state number from map
        const next_state = (self.transitions[current.transition_id + offset.byte] >> offset.shift) & offset.mask;
        return next_state;
    }

    pub fn next(
        self: Self,
        current: State,
        char: u7,
    ) u8 {
        const nextStateBase: usize = current.transition_id + bitmapSize(current.width);
        const next_state = self.nextStateId(current, char);
        // Resolve what actual state that maps to.
        return self.transitions[nextStateBase + next_state];
    }

    pub fn popSet(self: Self, comptime state: State) BitSet128 {
        // @setEvalBranchQuota(128);
        var popset = BitSet128.empty;
        for (0..128) |i| {
            if (self.states[self.next(state, @intCast(i))] == state) popset.set(i);
        }
        return popset;
    }

    pub const Header = packed struct(u40) {
        states: u8,
        transitions: u16,
        parseStart: u8,
        auxStart: u8,
    };

    pub fn write(self: Table, w: *std.Io.Writer) std.Io.Writer.Error!void {
        // Header - 5 bytes
        // count - u8 - You need u16 in order to represent 256, so instead, use u8 and do +1 since 0 is invalid.
        // start - u8 - Start state ID of the parser.
        // aux boundary - u8 - Kind ID of where aux kinds start.
        // Transitions len - u16 - similar +1
        try w.writeStruct(Table.Header{
            .states = @intCast(self.states.len - 1),
            .transitions = @intCast(self.transitions.len - 1),
            .parseStart = @intCast(self.parserStartId),
            .auxStart = @intCast(self.auxStart),
        }, .little);
        // States
        for (self.states) |state| {
            try w.writeStruct(state, .little);
        }
        try w.writeAll(self.transitions);
    }

    pub fn load(comptime bytes: []const u8) Table {
        return comptime blk: {
            var r = std.Io.Reader.fixed(bytes);

            const h = r.takeStruct(Table.Header, .little) catch @compileError("table load: Header error");
            const stateCount = @as(usize, h.states) + 1;
            const transitionCount = @as(usize, h.transitions) + 1;

            var states: [stateCount]State = undefined;
            for (&states) |*s| s.* = r.takeStruct(State, .little) catch @compileError("table load: State error");
            const finalStates = states;

            const transitions = r.take(transitionCount) catch @compileError("table load: Not enough transitions");
            if (r.seek != bytes.len) @compileError("table load err: trailing bytes");

            break :blk .{
                .states = &finalStates,
                .transitions = transitions,
                .parserStartId = h.parseStart,
                .auxStart = h.auxStart,
            };
        };
    }
};

const std = @import("std");
const termite = @import("../table/termite.zig");
const Table = termite.Table;

const States = enum(u8) { start, num, emit_num, plus, star, end, err };

fn Transition(comptime width: u2) type {
    return extern struct {
        bitmap: [Table.bitmapSize(width)]u8,
        next_states: [@as(usize, termite.ENTRY_WIDTH_MASKS[width]) + 1]u8,

        pub fn set(self: *@This(), char: u7, value: u8) void {
            const s = Table.slot(width, char);
            std.debug.assert(value <= s.mask);
            self.bitmap[s.byte] = (self.bitmap[s.byte] & ~(s.mask << s.shift)) | (value << s.shift);
        }

        pub fn setAll(self: *@This(), chars: []const u8, value: u8) void {
            for (chars) |ch| {
                self.set(@intCast(ch), value);
            }
        }

        pub fn route(self: *@This(), value: u8, chars: []const u8, target: States) void {
            self.setAll(chars, value);
            self.next_states[value] = @backingInt(target);
        }
    };
}

const Start = Transition(3);
const Num = Transition(0);
const DIGITS = "0123456789";

const Fixture = extern struct { start: Start, num: Num };
const fixture = blk: {
    var f = std.mem.zeroes(Fixture);
    f.start.route(0, "", .err);
    f.start.route(1, DIGITS, .num);
    f.start.route(2, "+", .plus);
    f.start.route(3, "*", .star);
    f.start.route(4, "\x00", .end);
    f.num.route(0, "", .emit_num);
    f.num.route(1, DIGITS, .num);
    break :blk f;
};

fn state(comptime field: []const u8, width: u2) Table.State {
    return .{
        .transition_id = @offsetOf(Fixture, field),
        .width = width,
        .consume = false,
        .op = .none,
        .arg = 0,
    };
}

const states = [_]Table.State{ state("start", 3), state("num", 0) };

const table = Table{ .states = &states, .transitions = std.mem.asBytes(&fixture) };

const Case = struct { from: States, sym: u7, to: States };
const cases = [_]Case{
    .{ .from = .start, .sym = '1', .to = .num },
    .{ .from = .num, .sym = '+', .to = .emit_num },
    .{ .from = .start, .sym = '+', .to = .plus },
    .{ .from = .start, .sym = '2', .to = .num },
    .{ .from = .start, .sym = '3', .to = .num },
    .{ .from = .start, .sym = '4', .to = .num },
    .{ .from = .num, .sym = '*', .to = .emit_num },
    .{ .from = .start, .sym = '*', .to = .star },
    .{ .from = .start, .sym = '5', .to = .num },
    .{ .from = .start, .sym = '6', .to = .num },
    .{ .from = .num, .sym = 0, .to = .emit_num },
    .{ .from = .start, .sym = 0, .to = .end },
};

test "1+234*56" {
    for (cases) |c| {
        errdefer std.debug.print("from {s} on {d}\n", .{ @tagName(c.from), c.sym });
        const got: States = @fromBackingInt(table.next(states[@backingInt(c.from)], c.sym));
        try std.testing.expectEqual(c.to, got);
    }
}

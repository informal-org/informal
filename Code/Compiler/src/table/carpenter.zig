const std = @import("std");
const tbl = @import("../table/table.zig");
const Table = tbl.Table;

pub fn Transition(comptime width: u2) type {
    return extern struct {
        bitmap: [Table.bitmapSize(width)]u8,
        next_states: [@as(usize, tbl.ENTRY_WIDTH_MASKS[width]) + 1]u8,

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

        pub fn route(self: *@This(), value: u8, chars: []const u8, target: u8) void {
            self.setAll(chars, value);
            self.next_states[value] = target;
        }
    };
}

// Empty string = Otherwise
pub const Route = struct { []const u8, u8 };
pub const StateRoute = struct {
    state: Table.State,
    on: []const Route,
};

fn route(op: Table.Op, consume: bool, arg: u8, routes: []const Route) StateRoute {
    const width = if (routes.len == 0) 0 else tbl.getWidthOf(@intCast(routes.len - 1));
    return StateRoute{
        .state = .{
            .op = op,
            .consume = consume,
            .arg = arg,
            .width = width,
            .transition_id = 0, // Will be filled in at a later stage.
        },
        .on = routes,
    };
}

pub fn build(comptime routes: []const StateRoute, comptime parser_start: u8, comptime aux_start: u8) Table {
    return comptime blk: {
        var states: [routes.len]Table.State = undefined;
        var transitions: []const u8 = &.{};
        for (routes, 0..) |r, i| {
            var state = r.state;
            if (r.on.len == 0) {
                state.transition_id = states[0].transition_id;
                state.width = states[0].width;
            }
        }
    };
}

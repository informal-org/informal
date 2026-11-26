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

const val = @import("value.zig");
const std = @import("std");
const print = std.debug.print;

pub const SYMBOL_COMMA = val.createStaticSymbol(',');
pub const SYMBOL_EQUALS = val.createStaticSymbol('=');
pub const SYMBOL_COLON = val.createStaticSymbol(':');
pub const SYMBOL_SEMI_COLON = val.createStaticSymbol(';');
pub const SYMBOL_OPEN_PAREN = val.createStaticSymbol('(');
pub const SYMBOL_CLOSE_PAREN = val.createStaticSymbol(')');
pub const SYMBOL_OPEN_SQBR = val.createStaticSymbol('[');
pub const SYMBOL_CLOSE_SQBR = val.createStaticSymbol(']');
pub const SYMBOL_OPEN_BRACE = val.createStaticSymbol('{');
pub const SYMBOL_CLOSE_BRACE = val.createStaticSymbol('}');
pub const SYMBOL_NEWLINE = val.createStaticSymbol('\n');
pub const SYMBOL_INDENT = val.createStaticSymbol('\t');
pub const SYMBOL_DEDENT = val.createStaticSymbol('D');

pub const T_TOKEN: u16 = 0x0010;
pub const T_IDENTIFIER: u16 = 0x0011;
pub const T_COMMENT: u16 = 0x0012;
pub const T_FORM: u16 = 0x0013;

// pub const SYMBOL_DOT = val.createStaticSymbol('.');
// pub const SYMBOL_QUOTE = val.createStaticSymbol('"');
// pub const SYMBOL_SINGLE_QUOTE = val.createStaticSymbol('\'');
// pub const SYMBOL_BACKSLASH = val.createStaticSymbol('\\');

// TODO: Emit New Line tokens.
// "locate" method to locate the line and column of a token.

pub fn createIdentifier(start: u24, length: u8) u64 {
    return val.createObject(T_IDENTIFIER, start, length);
}

pub fn createFormPtr(start: u24, length: u8) u64 {
    return val.createObject(T_FORM, start, length);
}

pub fn repr_type(token: u64) []const u8 {
    const t = val.getPrimitiveType(token);

    const tStr = switch (t) {
        val.TYPE_OBJECT => "Object",
        val.TYPE_OBJECT_ARRAY => "Array",
        val.TYPE_INLINE_OBJECT => "Inline Object",
        val.TYPE_PRIMITIVE_ARRAY => "Primitive Array",
        val.TYPE_INLINE_STRING => "Inline String",
        val.TYPE_INLINE_BITSET => "Inline Bitset",
        else => {
            if (val.isNan(token)) {
                return "NaN";
            } else {
                return "Number";
            }
        },
    };
    return tStr;
}

pub fn print_symbol(token: u64) void {
    const payload = val.getObjectPayload(token);
    _ = switch (payload) {
        val.SYMBOL_FALSE => print("False", .{}),
        val.SYMBOL_TRUE => print("True", .{}),
        val.SYMBOL_NONE => print("None", .{}),
        0...127 => {
            // Note: This is stack allocated and won't return properly.
            print("Symbol('{c}')", .{@truncate(u8, payload)});
        },
        else => print("Symbol({d})", .{payload}),
    };

    //  return repr;
}

// TODO: Buffer pointer?
pub fn print_object(token: u64, buffer: []const u8) void {
    const objType = val.getObjectType(token);
    _ = switch (objType) {
        T_IDENTIFIER => {
            const start = val.getObjectPtr(token);
            const length = val.getObjectLength(token);
            print("Identifier('{s}')", .{buffer[start..(start + length)]});
        },
        val.T_SYMBOL => {
            print_symbol(token);
        },
        else => {
            const payload = val.getObjectPayload(token);
            print("Object({x}_{x}) ", .{ objType, payload });
        },
    };
}

pub fn print_token(token: u64, buffer: []const u8) void {
    const t = val.getPrimitiveType(token);
    _ = switch (t) {
        val.TYPE_OBJECT, val.TYPE_INLINE_OBJECT => {
            print_object(token, buffer);
        },
        val.TYPE_OBJECT_ARRAY => {
            print("Array", .{});
        },
        val.TYPE_PRIMITIVE_ARRAY => {
            const start = val.getPrimitiveArrayPtr(token);
            const length = val.getPrimitiveArrayLength(token);

            if (start & 0x1000_0000 == 0x1000_0000) {
                // Top bit is set indicates a string.
                var bufferStart = start & 0x0FFF_FFFF;
                print("String(\"{s}\")", .{buffer[bufferStart..(bufferStart + length)]});
            } else {
                // Indicates a form. TODO;
                // print("String({x} => {d} - {d})", .{ token, start, length });
                print("Other Primitive Array {x} => {d} - {d}", .{ token, start, length });
            }
        },
        val.TYPE_INLINE_STRING => {
            var str2 = std.mem.zeroes([8]u8);
            val.decodeInlineString(token, &str2);
            print("String(\"{s}\")", .{str2});
        },
        val.TYPE_INLINE_BITSET => {
            print("Bitset({b})", .{val.getInlinePayload(token)});
        },
        else => {
            if (val.isNan(token)) {
                print("NaN({x})", .{token});
            } else {
                print("Number({d})", .{token});
            }
        },
    };
}

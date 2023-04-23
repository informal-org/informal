// const std = @import("std");

// pub fn main() !void {
//     // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
//     std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

//     // stdout is for the actual output of your application, for example if you
//     // are implementing gzip, then only the compressed bytes should be sent to
//     // stdout, not any debugging messages.
//     const stdout_file = std.io.getStdOut().writer();
//     var bw = std.io.bufferedWriter(stdout_file);
//     const stdout = bw.writer();

//     try stdout.print("Run `zig build test` to run the tests.\n", .{});

//     try bw.flush(); // don't forget to flush!
// }

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }

// const mlir = @import("mlir");
const mlir = @cImport({
    @cInclude("mlir-c/IR.h");
    @cInclude("mlir-c/BuiltinTypes.h");
});

// BuiltinTypes.h
// BuiltinAttributes.h

const std = @import("std");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // Context
    // Module
    // Insertion Point
    //     Operation - Global
    //     Operation - func main
    var ctx = mlir.mlirContextCreate();
    var locUnknonw = mlir.mlirLocationUnknownGet(ctx);

    var module = mlir.mlirModuleCreateEmpty(locUnknonw);
    var bodyBlock = mlir.mlirModuleGetBody(module);
    _ = bodyBlock;

    var int64 = mlir.mlirIntegerTypeGet(ctx, 64);
    _ = int64;

    // var printFlags = mlir.mlirOpPrintingFlagsCreate();
    // mlir.mlirOpPrintingFlags
    var modOp = mlir.mlirModuleGetOperation(module);
    mlir.mlirOperationDump(modOp);

    // var region = mlir.mlirRegionCreate();

    std.debug.print("Hello updated {} emit\n", .{mlir.mlirSymbolTableGetVisibilityAttributeName()});
}

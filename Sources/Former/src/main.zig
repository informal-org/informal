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
    @cInclude("mlir-c/BuiltinAttributes.h");
    @cInclude("mlir-c/Dialect/LLVM.h");
    @cInclude("mlir-c/Support.h");
});

// BuiltinTypes.h
// BuiltinAttributes.h

const std = @import("std");

// []const u8
fn stringRef(buffer: [:0]const u8) mlir.MlirStringRef {
    // const paramValues = [_][*:0]const u8{ "12", "me" };
    // There's also mlirStringRefCreateFromCString.
    return mlir.mlirStringRefCreate(buffer, buffer.len);
}

fn printStr(buffer: mlir.MlirStringRef, userdata: ?*anyopaque) callconv(.C) void {
    _ = userdata;
    const str = @ptrCast([*:0]const u8, buffer.data);
    std.debug.print("{s}", .{str[0..buffer.length]});
}

// fn createOp(opName: [:0]const u8, arg0: )

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // Context
    // Module
    // Insertion Point
    //     Operation - Global
    //     Operation - func main

    // Load the LLVM Dialect.
    var registry = mlir.mlirDialectRegistryCreate();
    var dialectLlvm = mlir.mlirGetDialectHandle__llvm__();
    // var dialectMemref = mlir.mlirGetDialectHandle__memref__();
    mlir.mlirDialectHandleInsertDialect(dialectLlvm, registry);
    // mlir.mlirDialectHandleInsertDialect(dialectMemref, registry);

    // mlir.mlirRegisterAllDialects(registry);

    // Setup base context with our dialects.
    var ctx = mlir.mlirContextCreate();
    var locUnknown = mlir.mlirLocationUnknownGet(ctx);
    mlir.mlirContextAppendDialectRegistry(ctx, registry);

    var module = mlir.mlirModuleCreateEmpty(locUnknown);
    var bodyBlock = mlir.mlirModuleGetBody(module);
    var modOp = mlir.mlirModuleGetOperation(module);
    var modSymbols = mlir.mlirSymbolTableCreate(modOp);

    // std.debug.print("module symbols: {any}\n", .{modSymbols});

    var int64 = mlir.mlirIntegerTypeGet(ctx, 64);
    var int32 = mlir.mlirIntegerTypeGet(ctx, 32);
    _ = int32;

    var sourceName = stringRef("test");

    // TODO: Originally "internal constant"
    var testOp = mlir.mlirOperationCreateParse(ctx, stringRef("llvm.mlir.global @myvar(\"hello, world\\0A\\00\")"), sourceName);
    // Symbol table insert will also implicitly add it into the body block.
    var symbolStr = mlir.mlirSymbolTableInsert(modSymbols, testOp);
    // _ = testSymbol;
    // var symLook = mlir.mlirSymbolTableLookup(modSymbols, stringRef("str"));
    // std.debug.print("Test symbol: {any} lookup {any}\n", .{ testSymbol, symLook });
    // mlir.mlirBlockAppendOwnedOperation(bodyBlock, testOp);

    mlir.mlirBlockAppendOwnedOperation(bodyBlock, mlir.mlirOperationCreateParse(ctx, stringRef("llvm.func @printf(!llvm.ptr<i8>, ...) -> i32"), sourceName));

    // Create the main function
    var mainRegion = mlir.mlirRegionCreate();
    // TODO: Use mlirTypeParseGet to give these names.
    var mainArgs = [_]mlir.MlirType{ int64, int64 };
    var mainArgsLocs = [_]mlir.MlirLocation{ locUnknown, locUnknown };
    var mainBlock = mlir.mlirBlockCreate(2, &mainArgs, &mainArgsLocs);
    mlir.mlirRegionAppendOwnedBlock(mainRegion, mainBlock);

    // TODO: Use block for function body.

    // Function end.
    var funcBuilderState = mlir.mlirOperationStateGet(stringRef("builtin.func"), locUnknown);
    // var xId = mlir.mlirIdentifierGet(ctx, stringRef("x"));
    // var xTypeAttr = mlir.mlirTypeAttrGet(int32);
    // var xArg = mlir.mlirNamedAttributeGet(xId, xTypeAttr);

    // TODO: Replace this with a mlirFunctionTypeGet
    var funcTypeAttr = mlir.mlirAttributeParseGet(ctx, stringRef("(i32, !llvm.ptr<ptr<i8>>) -> i32"));

    // The C-API doesn't seem to provide a direct way of setting the argument names - you get arg0, arg1, etc.
    // You *can* set an arg_attrs with llvm.name = "varname" for each arg, but that's not very useful.

    std.debug.print("funcTypeAttr: {any}\n", .{funcTypeAttr}); // TODO: Use mlirTypeParseGet to give these names.

    var funcNameAttr = mlir.mlirStringAttrGet(ctx, stringRef("main"));

    var funcAttrs = [_]mlir.MlirNamedAttribute{ mlir.mlirNamedAttributeGet(mlir.mlirIdentifierGet(ctx, stringRef("sym_name")), funcNameAttr), mlir.mlirNamedAttributeGet(mlir.mlirIdentifierGet(ctx, stringRef("function_type")), funcTypeAttr) };

    mlir.mlirOperationStateAddAttributes(&funcBuilderState, 2, &funcAttrs);

    var regions = [_]mlir.MlirRegion{mainRegion};
    mlir.mlirOperationStateAddOwnedRegions(&funcBuilderState, 1, &regions);

    // var mainFunc = mlir.mlirFuncOpCreate(locUnknown, stringRef("main"), 0, null, 2, &mainArgs, mainRegion, 0, null);

    var mainOp = mlir.mlirOperationCreate(&funcBuilderState);
    mlir.mlirBlockAppendOwnedOperation(bodyBlock, mainOp);

    // main block
    // mlir.mlirBlockAppendOwnedOperation(bodyBlock, mlir.mlirOperationCreateParse(ctx, stringRef("%1 = llvm.mlir.addressof @str : !llvm.ptr<array<14 x i8>>"), sourceName));
    mlir.mlirBlockAppendOwnedOperation(mainBlock, mlir.mlirOperationCreateParse(ctx, stringRef("%2 = llvm.mlir.constant(0: index) : i32"), sourceName));

    var parsedOp0 = mlir.mlirOperationCreateParse(ctx, stringRef("%1 = llvm.mlir.addressof @myvar : !llvm.ptr<array<14 x i8>>"), sourceName);

    // var op0 = mlir.mlirOperationStateGet(stringRef("llvm.mlir.addressof"), locUnknown);
    var op0Refs = [_]mlir.MlirAttribute{symbolStr};
    // var op0Refs = [_]mlir.MlirAttribute{mlir.mlirFlatSymbolRefAttrGet(ctx, stringRef("@str"))};
    // std.debug.print("op0Refs: {any}\n", .{op0Refs});

    var op0Uses = mlir.mlirArrayAttrGet(ctx, 1, &op0Refs);
    // var op0Attrs = [_]mlir.MlirNamedAttribute{mlir.mlirNamedAttributeGet(mlir.mlirIdentifierGet(ctx, stringRef("uses")), op0Uses)};
    // _ = op0Attrs;

    mlir.mlirOperationSetAttributeByName(parsedOp0, stringRef("uses"), op0Uses);

    // mlir.mlirBlockAppendOwnedOperation(mainBlock, parsedOp0);

    // var op0created = mlir.mlirOperationCreate(&op0);
    // mlir.mlirBlockAppendOwnedOperation(mainBlock, op0created);

    // var printFlags = mlir.mlirOpPrintingFlagsCreate();
    // mlir.mlirOpPrintingFlags

    // Emit MLIR IR directly to stderr.
    var printOptions = mlir.mlirOpPrintingFlagsCreate();
    // enable/disable debug info. Pretty form (un-parsable).
    mlir.mlirOpPrintingFlagsEnableDebugInfo(printOptions, false, false);
    mlir.mlirOpPrintingFlagsPrintGenericOpForm(printOptions);

    mlir.mlirOperationPrintWithFlags(modOp, printOptions, &printStr, null);

    // mlir.mlirOperationDump(modOp);

    // var region = mlir.mlirRegionCreate();

    // std.debug.print("Hello updated {} emit\n", .{mlir.mlirSymbolTableGetVisibilityAttributeName()});
}

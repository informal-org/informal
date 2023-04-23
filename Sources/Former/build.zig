const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const mlir = b.addStaticLibrary(.{ .name = "mlir-c", .target = target, .optimize = optimize });
    // const mlir = b.addSharedLibrary(.{ .name = "mlir", .target = target, .optimize = optimize });
    // mlir.setTarget(target);
    // mlir.setBuildMode(optimize);
    mlir.linkLibC(); // ?
    // mlir.linkLibCpp();
    mlir.force_pic = true;
    mlir.addIncludePath("../../../llvm-project/mlir/include");
    mlir.addLibraryPath("../../../llvm-project/build/lib");
    mlir.addLibraryPath("../../../llvm-project/build/tools/mlir/lib");

    // mlir.linkLibC();
    // TODO - Make libpath configurable.
    mlir.addCSourceFiles(&.{
        "../../../llvm-project/mlir/include/mlir-c/AffineExpr.h",
        "../../../llvm-project/mlir/include/mlir-c/AffineMap.h",
        "../../../llvm-project/mlir/include/mlir-c/BuiltinAttributes.h",
        "../../../llvm-project/mlir/include/mlir-c/BuiltinTypes.h",
        // "../../../llvm-project/mlir/include/mlir-c/Conversion.h",
        "../../../llvm-project/mlir/include/mlir-c/Debug.h",
        "../../../llvm-project/mlir/include/mlir-c/Diagnostics.h",
        "../../../llvm-project/mlir/include/mlir-c/ExecutionEngine.h",
        "../../../llvm-project/mlir/include/mlir-c/IntegerSet.h",
        // "../../../llvm-project/mlir/include/mlir-c/Interfaces.h",
        "../../../llvm-project/mlir/include/mlir-c/IR.h",
        "../../../llvm-project/mlir/include/mlir-c/Pass.h",
        // "../../../llvm-project/mlir/include/mlir-c/RegisterEverything.h",
        // "../../../llvm-project/mlir/include/mlir-c/Support.h",
        // "../../../llvm-project/mlir/include/mlir-c/Transforms.h",
        // "../../../llvm-project/mlir/include/mlir-c/Dialect/Async.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/ControlFlow.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/Func.h",
        // "../../../llvm-project/mlir/include/mlir-c/Dialect/GPU.h",
        // "../../../llvm-project/mlir/include/mlir-c/Dialect/Linalg.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/LLVM.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/MLProgram.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/PDL.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/Quant.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/SCF.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/Shape.h",
        // "../../../llvm-project/mlir/include/mlir-c/Dialect/SparseTensor.h",
        "../../../llvm-project/mlir/include/mlir-c/Dialect/Tensor.h",
        // "../../../llvm-project/mlir/include/mlir-c/Dialect/Transform.h",
    }, &.{}); // "-std=c99", "-Wall"
    b.installArtifact(mlir);

    const exe = b.addExecutable(.{
        .name = "Former",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // exe.createModule()
    exe.addLibraryPath("../../../llvm-project/build/lib");
    // exe.addLibraryPath("../../../llvm-project/build/tools/mlir/lib");
    // exe.addLibraryPath("../../../llvm-project/build/tools/mlir/lib/CAPI/IR/CMakeFiles/obj.MLIRCAPIIR.dir");
    // exe.addLibraryPath("../../../llvm-project/build/tools/mlir/lib/IR/CMakeFiles/obj.MLIRCAPIIR.dir");
    // exe.linkSystemLibrary("mlir");
    // exe.linkSystemLibraryName("MLIRCAPIIR");
    // exe.linkSystemLibraryName("MLIRCAPIAsync");
    // exe.linkSystemLibraryName("MLIRCAPIControlFlow");
    // exe.linkSystemLibraryName("MLIRCAPIConversion");
    // exe.linkSystemLibraryName("MLIRCAPIDebug");
    // exe.linkSystemLibraryName("MLIRCAPIExecutionEngine");
    // exe.linkSystemLibraryName("MLIRCAPIFunc");
    // exe.linkSystemLibraryName("MLIRCAPIGPU");
    // exe.linkSystemLibraryName("MLIRCAPIInterfaces");
    // exe.linkSystemLibraryName("MLIRCAPIIR");
    // exe.linkSystemLibraryName("MLIRCAPILinalg");
    // exe.linkSystemLibraryName("MLIRCAPILLVM");
    // exe.linkSystemLibraryName("MLIRCAPIMLProgram");
    // exe.linkSystemLibraryName("MLIRCAPIPDL");
    // exe.linkSystemLibraryName("MLIRCAPIPythonTestDialect");
    // exe.linkSystemLibraryName("MLIRCAPIQuant");
    // exe.linkSystemLibraryName("MLIRCAPIRegisterEverything");
    // exe.linkSystemLibraryName("MLIRCAPISCF");
    // exe.linkSystemLibraryName("MLIRCAPIShape");
    // exe.linkSystemLibraryName("MLIRCAPISparseTensor");
    // exe.linkSystemLibraryName("MLIRCAPITensor");
    // exe.linkSystemLibraryName("MLIRCAPITransformDialect");
    // exe.linkSystemLibraryName("MLIRCAPITransforms");
    exe.linkSystemLibraryName("MLIR-C");

    exe.addIncludePath("../../../llvm-project/mlir/include");

    exe.linkLibC();
    // exe.linkLibrary(mlir);

    // exe.linkSystemLibrary("mlir");

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a RunStep in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

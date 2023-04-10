

# MLIR Hello World

mlir-opt hello.mlir --convert-func-to-llvm > hello_stage2.mlir
mlir-translate --mlir-to-llvmir hello_stage2.mlir > hello.ll
clang hello.ll --output hello.out

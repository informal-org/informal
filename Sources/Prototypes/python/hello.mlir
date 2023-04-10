// Original credit:
// https://www.politesi.polimi.it/bitstream/10589/179218/1/Thesis.pdf

llvm.mlir.global internal constant @str("hello, world\0A\00")

llvm.func @printf(!llvm.ptr<i8>, ...) -> i32

llvm.func @main(%argc: i32, %argv: !llvm.ptr<ptr<i8>>) -> i32 {
    // %0 = llvm.mlir.addressof @str: !llvm.ptr<array<14 x i8>>
    %0 = llvm.mlir.addressof @str :  !llvm.ptr<array<14 x i8>>
    // %0 = llvm.mlir.addressof @str: !llvm.ptr<i8>
    %1 = llvm.mlir.constant(0: index) : i32
    %2 = llvm.getelementptr %0[%1, %1] : (!llvm.ptr<array<14 x i8>>, i32, i32) -> !llvm.ptr<i8>
    // %2 = llvm.getelementptr %0[%1, %1] : (!llvm.ptr<i8>, i32, i32) -> !llvm.ptr<i8>
    %3 = llvm.call @printf(%2) : (!llvm.ptr<i8>) -> i32
    %4 = llvm.mlir.constant(0: i32) : i32
    llvm.return %4 : i32
}
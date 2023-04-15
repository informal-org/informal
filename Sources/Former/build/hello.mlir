
llvm.mlir.global internal constant @str("%d\0A\00")
llvm.func @printf(!llvm.ptr<i8>, ...) -> i32 
llvm.func @main(%argc: i32, %argv: !llvm.ptr<ptr<i8>>) -> i32 {
	%1 = llvm.mlir.addressof @str : !llvm.ptr<array<4 x i8>>
	%2 = llvm.mlir.constant(0 : index) : i32
	%3 = llvm.getelementptr %1[%2, %2] : (!llvm.ptr<array<4 x i8>>, i32, i32) -> !llvm.ptr<i8>
	%4 = llvm.mlir.constant(1 : i32) : i32
	%5 = llvm.mlir.constant(2 : i32) : i32
	%6 = llvm.mlir.constant(4 : i32) : i32
	%7 = llvm.mul %5, %6 :  i32
	%8 = llvm.add %4, %7 :  i32
	%9 = llvm.call @printf(%3, %8) : (!llvm.ptr<i8>, i32) -> i32
	%10 = llvm.mlir.constant(0 : i32) : i32
	llvm.return %10 : i32
}



; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

@str = internal constant [4 x i8] c"%d\0A\00"

declare ptr @malloc(i64)

declare void @free(ptr)

declare i32 @printf(ptr, ...)

define i32 @main(i32 %0, ptr %1) {
  %3 = call i32 (ptr, ...) @printf(ptr @str, i32 9)
  ret i32 0
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}

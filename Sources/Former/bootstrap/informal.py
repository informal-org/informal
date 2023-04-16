from mlirgen import *
from primitives import *
from ast import *
import sys
import argparse
import os
        

def gen_mlir(expr):
    # To get visibility into running results
    # This first version will rely on C-libraries to do things like
    # digit to char. Or printf.
    # The code automatically runs in main and will print the result.
    ctx = CodeBuffer()
    with Module(ctx) as module:
        terminator = '\\0A\\00'
        message = """%d"""
        # Message length + 2 byte terminator length.
        input_type = f'!llvm.ptr<array<{len(message) + 2} x i8>>'
        module.line(f'llvm.mlir.global internal constant @str("{message + terminator}")')
        module.builtin_printf.code(module)
        with Main(ctx) as main:
            l0 = Pointer(main,"str", input_type).code()
            l1 = Constant(main, 0, "index", i32).code()
            l2 = ElementIndex(main, l0, l1, l1, input_type).code()
            expr_result = expr.emit(main)
            l3 = module.builtin_printf.overload_call(main, ["!llvm.ptr<i8>", i32], [l2, expr_result])
            l4 = Constant(main, 0, i32).code()
            main.line(f"llvm.return {l4} : i32")
    print(ctx.code)


def compile_file(filename, emit_ast=False):
    filepath = os.path.join(os.getcwd(), filename)
    with open(filepath, 'r') as f:
        code = f.read()
    result = parse(code)
    if emit_ast:
        print(result.repr())
    else:
        gen_mlir(result)


def get_file_args():
    if len(sys.argv) == 1:
        print("Please provide a filename")
        exit(1)
    return sys.argv[1]

if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument("filename", help="The file to compile")
    arg_parser.add_argument("--emit-ast", action="store_true", help="Print the AST")
    args = arg_parser.parse_args()
    print(args)
    compile_file(args.filename, args.emit_ast)
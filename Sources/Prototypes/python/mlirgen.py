from collections import namedtuple, defaultdict

class CodeBuffer:
    """
    Shared buffer for code-generation.
    """
    def __init__(self):
        self.code = ""

class Context:
    def __init__(self, ctx, indent=0):
        self.ctx = ctx
        self.indent = indent
        self._nextLocal = 0
        self._nextVarId = defaultdict(int)

    def nextLocal(self):
        self._nextLocal += 1
        return f"%{self._nextLocal}"
    
    def ref(self, name):
        # Reference the current version of a variable by name.
        return f"%{name}_{self._nextVarId[name]}"

    def assign(self, name, value, type):
        self._nextVarId[name] += 1
        ssa_var = self.variable(name)
        self.line(f"{ssa_var} = {value} : {type}")
        return ssa_var
    
    def assignLocal(self, value, type):
        local_id = self.nextLocal()
        self.line(f"{local_id} = {value} : {type}")
        return local_id
    
    def line(self, value, indent=0):
        active_indent = indent or (self.indent + 1 if self.prelude else self.indent)
        self.ctx.code += ('\t' * (active_indent)) + value + "\n"

    def __enter__(self):
        self.line(self.prelude, indent=self.indent - 1)
        return self
    
    def __exit__(self, type, value, traceback):
        self.line(self.conclude, indent=self.indent - 1)

Var = namedtuple("Var", ["name", "type"])

class Func(Context):
    def __init__(self, ctx, name, params, ret_type, *args, **kwargs):
        super().__init__(ctx, *args, **kwargs)
        param_str = ", ".join([f"%{name}: {type}" for name, type in params])
        self.prelude = f"llvm.func @{name}({param_str}) -> {ret_type} " + "{"
        self.conclude = "}"

    
class Op(Context):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.args = args
        self.kwargs = kwargs

class Global(Op):
    name = "llvm.mlir.global"
    
class Module(Context):
    def __init__(self, ctx):
        super().__init__(ctx)
        self.prelude = ""
        self.conclude = ""

i32 = "i32"


def test_gen():
    ctx = CodeBuffer()
    with Module(ctx) as module:
        terminator = '\\0A\\00'
        message = "Hello, Feni!"
        # Message length + 2 byte terminator length.
        input_type = f'!llvm.ptr<array<{len(message) + 2} x i8>>'
        module.line(f'llvm.mlir.global internal constant @str("{message + terminator}")')
        module.line('llvm.func @printf(!llvm.ptr<i8>, ...) -> i32')
        with Func(ctx, "main", [Var("argc", "i32"), Var("argv", "!llvm.ptr<ptr<i8>>")], "i32") as func:
            l0 = func.assignLocal('llvm.mlir.addressof @str', input_type)
            l1 = func.assignLocal('llvm.mlir.constant(0: index)', i32)
            l2 = func.assignLocal(f'llvm.getelementptr {l0}[{l1}, {l1}]', f'({input_type}, i32, i32) -> !llvm.ptr<i8>')
            l3 = func.assignLocal(f'llvm.call @printf({l2})', '(!llvm.ptr<i8>) -> i32')
            l4 = func.assignLocal(f'llvm.mlir.constant(0: i32)', i32 )
            func.line(f"llvm.return {l4} : i32")

    print(ctx.code)

test_gen()
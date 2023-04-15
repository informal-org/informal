from collections import namedtuple, defaultdict

class CodeBuffer:
    """
    Shared buffer for code-generation.
    """
    def __init__(self):
        self.code = ""

    def line(self, value):
        self.code += value + "\n"

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
    name = 'llvm.func'
    def __init__(self, ctx, name, params, ret_type, *args, **kwargs):
        super().__init__(ctx, *args, **kwargs)
        self.name = name
        self.params = params
        self.ret_type = ret_type
        param_str = ", ".join([f"%{name}: { type }" for name, type in params])
        self.declaration = f"llvm.func @{name}({param_str}) -> {ret_type} "
        self.prelude = self.declaration + "{"
        self.conclude = "}"

    def call_code(self, ctx, params, param_type):
        # llvm.call @printf({l2})', '(!llvm.ptr<i8>) -> i32'
        return ctx.assignLocal(f"llvm.call @{self.name}({ ', '.join(params) })", 
                               f'{param_type} -> {self.ret_type}')
    
    # def define_external(self, ctx):
    #     return ctx.line(f'llvm.func @{name}(!llvm.ptr<i8>, ...) -> i32')

class ExternalFunc(Context):
    def __init__(self, ctx, name, params_type, ret_type, *args, **kwargs):
        super().__init__(ctx, *args, **kwargs)
        self.name = name
        self.params_type = params_type
        self.ret_type = ret_type
        param_str = ", ".join(params_type)
        self.declaration = f"llvm.func @{name}({param_str}) -> {ret_type} "

    def code(self, ctx=None):
        return (ctx or self.ctx).line(self.declaration)

    def call_code(self, ctx, params):
        return self.overload_call(ctx, self.params_type, params)
    
    def overload_call(self, ctx, fn_signature, params):
        params_type = [p for p in fn_signature if p != '...']
        return ctx.assignLocal(f"llvm.call @{self.name}({ ', '.join(params) })",
                              f'({", ".join(params_type)}) -> {self.ret_type}')


class Main(Func):
    def __init__(self, ctx, *args, **kwargs):
        argmain = [Var("argc", "i32"), Var("argv", "!llvm.ptr<ptr<i8>>")]
        super().__init__(ctx, "main", argmain, i32, *args, **kwargs)
    
class Op(Context):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.args = args
        self.kwargs = kwargs

class Global(Op):
    name = "llvm.mlir.global"


class Constant(Op):
    name = 'llvm.mlir.constant'

    def __init__(self, ctx, value, input_type, return_type=None):
        super().__init__(ctx)
        self.value = value
        self.input_type = input_type
        self.return_type = return_type or input_type

    def code(self, ctx=None):
        return (ctx or self.ctx).assignLocal(f'{self.name}({self.value} : {self.input_type})', self.return_type)


class Module(Context):
    def __init__(self, ctx):
        super().__init__(ctx)
        # Prelude - import standard library.
        self.prelude = ""
        self.conclude = ""
        self.builtin_printf = ExternalFunc(ctx, "printf", ["!llvm.ptr<i8>", "..."], i32)



class Pointer(Op):
    name = 'llvm.mlir.addressof'
    def __init__(self, ctx, ref, return_type):
        super().__init__(ctx)
        self.ref = ref
        self.return_type = return_type
    
    def code(self, ctx=None):
        return (ctx or self.ctx).assignLocal(f'{self.name} @{self.ref}', self.return_type)



class ElementIndex(Op):
    # LLVM GetElementPtr (GEP).
    # x = &Foo[0].F;
    # Base address + offset.
    name = 'llvm.getelementptr'

    def __init__(self, ctx, ref, base, offset, input_type, return_type='!llvm.ptr<i8>'):
        super().__init__(ctx)
        self.base = base
        self.offset = offset
        self.ref = ref
        self.input_type = input_type
        self.return_type = return_type
        self.type = f'({input_type}, i32, i32) -> {return_type}'
    
    def code(self, ctx=None):
        return (ctx or self.ctx).assignLocal(f'{self.name} {self.ref}[{self.base}, {self.offset}]', self.type)




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


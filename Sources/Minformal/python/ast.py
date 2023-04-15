from primitives import *
from mlirgen import *


def precedence_gte(node_bp, context_bp):
    return node_bp >= context_bp


def precedence_gt(node_bp, context_bp):
    return node_bp > context_bp


class DependentNode(Type):
    def __init__(self, binding_power):
        super().__init__()
        self.binding_power = binding_power
        self.rest = ""
        self.result = None

    def match(self, input_):
        self.result = self.option.match(input_)
        if self.result:
            self.rest = self.result.rest
            return self
        else:
            return None

    def repr(self, indent=0):
        prefix = '\n' + ('\t' * indent)
        return prefix + self.__class__.__name__ + " " + self.result.repr(indent+1)
    
    def emit(self, ctx):
        return self.result.emit(ctx)


class BinaryOp(DependentNode):
    op = None
    op_binding_power = None

    def __init__(self, binding_power):
        super().__init__(binding_power)
        self.option = Structure(
            Intersection(lambda x: precedence_gt(self.op_binding_power, binding_power), Expr(self.op_binding_power)),
            ParseLiteral(self.op),
            Intersection(lambda x: precedence_gte(self.op_binding_power, binding_power), Expr(self.op_binding_power)),
        )

    def emit(self, ctx):
        lhs = self.result.values[0].emit(ctx)
        rhs = self.result.values[2].emit(ctx)
        op = Op(ctx)
        return op.create(
            ctx, self.operation, result=i32, operands=[lhs, rhs])



class AddNode(BinaryOp):
    op = "+"
    op_binding_power = 10
    operation = "llvm.add"


class MultiplyNode(BinaryOp):
    op = "*"
    op_binding_power = 20
    operation = "llvm.mul"


class NumericLiteral(Type):
    def match(self, input_):
        if len(input_) > 0 and input_[0].isdigit():
            self.value = input_[0]
            self.rest = input_[1:]
            return self
        else:
            return None
    
    def repr(self, indent=0):
        prefix = '\n' + ('\t' * indent)
        return f"{prefix}NumericLiteral({self.value})"
    
    def emit(self, ctx):
        return Constant(ctx, int(self.value), i32).code()

class Expr(DependentNode):
    def __init__(self, binding_power):
        super().__init__(binding_power)
        self.binding_power = binding_power
        # Don't initialize options here to prevent recursion. 
        # In the proper version, the types are chained - so the initial condition can short-circut the other
        # type checks and acts like a base-case to prevent infinite recursion.

    def match(self, input):
        self.option = Choice(
            AddNode(self.binding_power),
            MultiplyNode(self.binding_power),
            NumericLiteral()
        )
        self.result = match(input, self.option)
        if self.result:
            self.rest = self.result.rest
            return self
        else:
            return None
        
    def emit(self, ctx):
        return self.result.emit(ctx)
                

class ParseLiteral(LiteralType):
    def emit(self, ctx):
        # These are temporary nodes just used during parsing
        pass


def parse(input_):
    # Recursive descent, pratt-style parser using dependent types.
    tokens = input_.split(" ")
    base = Expr(0)
    result = match(tokens, base)
    return result
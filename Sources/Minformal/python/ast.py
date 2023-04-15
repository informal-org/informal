from primitives import *
from mlirgen import *


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
    

def precedence_gte(node_bp, context_bp):
    return node_bp >= context_bp


def precedence_gt(node_bp, context_bp):
    return node_bp > context_bp


class InfixOp(DependentNode):
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
    

class InfixRightOp(InfixOp):
    def __init__(self, binding_power):
        super().__init__(binding_power)
        self.option = Structure(
            # For right-associative, require left node has 
            Intersection(lambda x: precedence_gt(self.op_binding_power, binding_power + 1), Expr(self.op_binding_power)),
            ParseLiteral(self.op),
            Intersection(lambda x: precedence_gt(self.op_binding_power, binding_power), Expr(self.op_binding_power)),
        )

# TODO - Verify - precedence climbing for mixfix case.
# class MixfixOp(InfixOp):
#     def __init__(self, binding_power):
#         super().__init__(binding_power)
#         self.option = Structure(
#             Intersection(lambda x: precedence_gt(self.op_binding_power, binding_power), Expr(self.op_binding_power)),
#             ParseLiteral(self.op),
#             Intersection(lambda x: precedence_gt(self.op_binding_power, binding_power), Expr(self.op_binding_power)),
#         )


class PrefixOp(DependentNode):
    op = None
    op_binding_power = None

    def __init__(self, binding_power):
        super().__init__(binding_power)
        self.option = Structure(
            ParseLiteral(self.op),
            Intersection(lambda x: precedence_gt(self.op_binding_power, binding_power), Expr(self.op_binding_power)),
        )

    def emit(self, ctx):
        rhs = self.result.values[1].emit(ctx)
        op = Op(ctx)
        return op.create(
            ctx, self.operation, result=i32, operands=[rhs])


class AddNode(InfixOp):
    op = "+"
    op_binding_power = 80
    operation = "llvm.add"


class SubNode(InfixOp):
    op = "-"
    op_binding_power = 80
    operation = "llvm.sub"


class MulNode(InfixOp):
    op = "*"
    op_binding_power = 85
    operation = "llvm.mul"


class DivNode(InfixOp):
    op = "/"
    op_binding_power = 85
    operation = "llvm.div"

class ModNode(InfixOp):
    op = "%"
    op_binding_power = 85
    operation = "llvm.mod"


class PowNode(InfixRightOp):
    op = "^"
    op_binding_power = 88
    operation = "llvm.pow"



# A : B
class AsocNode(InfixRightOp):
    op = ":"
    op_binding_power = 50
    # TODO


class DsocNode(InfixRightOp):
    op = "::"
    op_binding_power = 57       # ?
    # TODO


class EqNode(InfixRightOp):
    op = "="
    op_binding_power = 55
    # TODO


# TODO: Treat this more like a grouping op.
class BlockNode(PrefixOp):
    op = "\n"
    op_binding_power = 100


class AndNode(InfixOp):
    op = "and"
    op_binding_power = 25
    operation = "llvm.and"


class OrNode(InfixOp):
    op = "or"
    op_binding_power = 24
    operation = "llvm.or"


class LTOp(InfixOp):
    op = "<"
    op_binding_power = 40
    # Signed less than
    operation = "llvm.icmp slt"

class GtOp(InfixOp):
    op = ">"
    op_binding_power = 40
    operation = "llvm.icmp sgt"

class GTEOp(InfixOp):
    op = ">="
    op_binding_power = 40
    operation = "llvm.icmp sge"

class LTEOp(InfixOp):
    op = "<="
    op_binding_power = 40
    operation = "llvm.icmp sle"


# TODO: Not - mixfix. TODO? is not. not in.
# No primitive not op - https://lists.llvm.org/pipermail/llvm-dev/2015-April/084376.html

# TODO: Grouping.


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
            SubNode(self.binding_power),
            MulNode(self.binding_power),
            DivNode(self.binding_power),
            ModNode(self.binding_power),
            PowNode(self.binding_power),
            AsocNode(self.binding_power),
            EqNode(self.binding_power),
            AndNode(self.binding_power),
            OrNode(self.binding_power),
            LTOp(self.binding_power),
            GtOp(self.binding_power),
            GTEOp(self.binding_power),
            LTEOp(self.binding_power),
            NumericLiteral()        # Can I move this top?
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
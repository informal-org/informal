PRECEDENCE_ADD = 10
PRECEDENCE_MULTIPLY = 20


class Type:
    def match(self):
        return self

    def repr(self, indent=0):
        prefix = '\n' + ('\t' * indent)
        return prefix + self.__class__.__name__


class CompoundType(Type):
    def __init__(self, *options):
        super().__init__()
        self.options = options
        self.value = []
        self.rest = ""

    def repr(self, indent=0):
        prefix = '\n' + ('\t' * indent)
        return prefix + self.__class__.__name__ + "()"


class LiteralType(Type):
    def __init__(self, value):
        super().__init__()
        self.value = value
        self.rest = ""

    def match(self, input_):
        if len(input_) > 0 and self.value == input_[0]:
            self.rest = input_[1:]
            return self
        else:
            return None

    def repr(self, indent=0):
        prefix = '\n' + ('\t' * indent)
        return f"{prefix}Literal({self.value})"


class Intersection(CompoundType):
    def match(self, input_):
        values = []
        for option in self.options:
            result = match(input_, option)
            if not result:
                return None
            values.append(result)
        self.values = values
        # self.rest = input_[1:]
        self.rest = values[-1].rest
        return self

    def repr(self, indent=0):
        last_val = self.values[-1]
        prefix = '\n' + ('\t' * indent)
        return f"{prefix}Intersection({prefix}{ last_val.repr(indent+1) if isinstance(last_val, Type) else last_val})"


class Choice(CompoundType):
    def match(self, input_):
        for option in self.options:
            result = match(input_, option)
            if result:
                self.rest = input_[1:]
                return result
        return None


class Structure(CompoundType):
    def match(self, input_):
        self.rest = input_
        values = []
        for option in self.options:
            result = match(self.rest, option)
            if not result:
                return None
            values.append(result)
            self.rest = result.rest
        self.values = values
        return self

    def repr(self, indent=0):
        # return f"Structure{{{'; '.join([v.repr() if isinstance(v, Type) else v for v in self.values])}}}"
        # Print this indented as a tree
        prefix = '\n' + ('\t' * indent)
        return f"{prefix}Structure{{{ prefix.join([v.repr(indent + 1) if isinstance(v, Type) else (prefix + v) for v in self.values])}}}"

def match(input_, type_):
    if isinstance(type_, Type):
        return type_.match(input_)
    elif isinstance(type_, bool):
        return input_ if type_ else None
    elif callable(type_):
        return match(input_, type_(input_))
    else:
        raise ValueError(f"Unknown type: {type(type_)}")


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


class AddNode(DependentNode):
    def __init__(self, binding_power):
        super().__init__(binding_power)
        self.option = Structure(
            Intersection(lambda x: precedence_gt(PRECEDENCE_ADD, binding_power), Expr(PRECEDENCE_ADD)),
            LiteralType("+"),
            Intersection(lambda x: precedence_gte(PRECEDENCE_ADD, binding_power), Expr(PRECEDENCE_ADD)),
        )


class MultiplyNode(DependentNode):
    def __init__(self, binding_power):
        super().__init__(binding_power)
        self.option = Structure(
            Intersection(lambda x: precedence_gt(PRECEDENCE_MULTIPLY, binding_power), Expr(PRECEDENCE_MULTIPLY)),
            LiteralType("*"),
            Intersection(lambda x: precedence_gte(PRECEDENCE_MULTIPLY, binding_power), Expr(PRECEDENCE_MULTIPLY)),
        )

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
                

def parse(input_):
    tokens = input_.split(" ")
    base = Expr(0)
    result = match(tokens, base)
    print(result.repr())
    print("Rest:", result.rest)
    # TODO: Need to wrap this in a Many() to ensure the full expression is parsed.

# parse("1 + 2 * 3")
parse("1 * 2 + 3")
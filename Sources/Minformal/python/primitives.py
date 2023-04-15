from mlirgen import *


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
    
    def emit(self, ctx):
        return Constant(ctx, int(self.value), i32).code()


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
    
    def emit(self, ctx):
        result = self.values[-1].emit(ctx)
        return result


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
    
    def emit(self, ctx):
        result = None
        for val in self.values:
            result = val.emit(ctx)
        return result


def match(input_, type_):
    if isinstance(type_, Type):
        return type_.match(input_)
    elif isinstance(type_, bool):
        return input_ if type_ else None
    elif callable(type_):
        return match(input_, type_(input_))
    else:
        raise ValueError(f"Unknown type: {type(type_)}")



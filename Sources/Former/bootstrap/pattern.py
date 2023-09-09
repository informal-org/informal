
class Literal:
    def __init__(self, value):
        # TODO: Auto convert a string into a compound list of characters.
        self.value = value
        self.compiled = value

    def compile(self):
        pass

class Choice:
    """
    A choice of patterns. One must match for it to match.
    """
    def __init__(self, *values):
        self.values = values
        self.compiled = {}

    def compile(self):
        self.compiled = {}
        for value in self.values:
            if isinstance(value, Literal):
                self.compiled[value.value] = value
            elif isinstance(value, Choice):
                value.compile()
                # Choice of choices = choice.
                self.compiled.update(value.compiled)
            elif isinstance(value, Compound):
                # Choice of compound = first bit of it. Then the rest.
                value.compile()
                if len(value.values) == 0:
                    continue
                elif len(value.values) == 1:
                    c = value.values[0].compile()
                    self.compiled[] = Literal(*value.values[0])
                else:
                    self.compiled[value.values[0]] = Compound(*value.values[1:])
            


class Compound:
    """
    Composed of smaller types. All must match in sequence for it to match.
    """
    def __init__(self, *values):
        self.values = values
        self.compiled = None

    def compile(self):
        compiled = []
        if len(self.values) == 0:
            self.compiled = []
        elif len(self.values) == 1:
            self.compiled = self.values[0].compile()
        else:
            self.compiled = [v.compile() for v in self.values]
        

class Intersection:
    """
    All must match for it to match.
    """
    def __init__(self, *values):
        self.values = values
        self.compiled = None


def compile(pattern):
    if isinstance(pattern, Literal):
        return pattern
    elif isinstance(pattern, Choice):
        # Assuming everything is lookup-able.
        choice_map = {}

        for value in pattern.values:
            if isinstance(value, Literal):
                choice_map[value.value] = value
            elif isinstance(value, Choice):
                choice_map.update(compile(value))
            elif isinstance(value, Compound):
                choice_map[value.values[0]] = Compound()

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
    A | B | C
    """
    def __init__(self, *values):
        self.values = values
        self.compiled = {}

    def blahcompile(self):
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

    def compile(self):
        # Merge duplicate choices
        # Merge the choices such that no two paths are overlapping.
        # Returns - a list of choices, with some choices being replaced by their merged counterparts and duplicates eliminated.
        options = {}
        for choice in self.choices:
            key = None
            value = None

            if isinstance(choice, Literal):
                key = choice.value
                value = choice
            elif isinstance(choice, Compound):
                # TODO: Handle empty, one node -> literal, etc.
                key = choice.values[0]    # TODO: How to simplify this recursively?
                value = Compound(*choice.values[1:])
            # TODO: Intersection.

            if key in options:
                # Merge the two. The key remains the same, but both values are merged.
                pass
            else:
                options[key] = value

    def merge(self, other):
        # Merge two things together.
        if isinstance(other, Choice):
            # TODO: Does this need to deduplicate first?
            return Choice(*self.values, *other.values)
        elif isinstance(other, Literal):
            # Two interpretations possible. One is that the literal takes priority, even though it comes after (greedy)
            # The other is that we preserve pattern order, so only if the choice fails do we try the literal.
            # TODO: Dedupe?
            return Choice(*self.values, other.value)
        elif isinstance(other, Compound):
            # TODO
            pass            


class Compound:
    """
    Composed of smaller types. All must match in sequence for it to match.
    A -> B -> C 
    """
    def __init__(self, *values):
        self.values = values
        self.original = None   # Reference to the original pre-compiled version of this pattern.

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
    A & B & C
    """
    def __init__(self, *values):
        self.values = values
        self.compiled = None




def compile(pattern):
    # Compile the pattern into an equivalent pattern that can be matched without backtracking.
    # The core of this is to merge duplicate paths, or split up divide overlapping subsets into a shared path.
    # such that each choice and operation always progresses forward.
    if isinstance(pattern, Literal):
        return pattern
    elif isinstance(pattern, Choice):
        return merge_choices(pattern.values)
    elif isinstance(pattern, Compound):
        return merge_compound(pattern.values)
    

def test_choices():
    # AB | AC -> A (B | C)
    ab = Choice(Compound(Literal("A", "B")), Compound(Literal("A", "C")))
    ab.compile()

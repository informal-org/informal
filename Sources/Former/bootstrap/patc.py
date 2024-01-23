# Patc (Patsy) is a pattern -> table compiler.
from typing import List, Union, Optional


class Pattern:
    def __init__(self):
        pass


class Choice(Pattern):
    def __init__(self, variants: List[Union[Pattern, str]]):
        self.variants = variants
        super().__init__()


class Sequence(Pattern):
    def __init__(self, elements: List[Union[Pattern, str]]):
        self.elements = elements
        super().__init__()


example = Choice(["cat", "car"])


def eliminate_left_recursion(pattern: Pattern) -> Pattern:
    # TODO: Eliminate cyclical left recursion.
    return pattern


# We'll keep the original choice structure for now since it might have semantic meaning for presedence.
# def consolidate_choice_of_choices(pattern: Pattern) -> Pattern:
#     if isinstance(pattern, Choice):
#         variants = []
# 

def get_prefix(pattern: Union[Pattern, str]) -> Optional[str]:
    if isinstance(pattern, str):
        return pattern[0], pattern[1:]
    elif isinstance(pattern, Sequence):
        return Sequence()
    


def merge_common_prefix(pattern: Pattern) -> Pattern:
    # TODO: Merge common prefixes. Eliminates the need for backtracking.
    if isinstance(pattern, Choice):
        prefixes = {}

        # for variant in pattern.variants:
        #     if isinstance(variant, Choice):
        #         for subvariant in variant.variants:

        #     elif isinstance(variant, Sequence):
        #         prefixes[variant.element[0]]
        #     elif isinstance(variant, str):
                
        #     else:
        #         raise TypeError("Unknown pattern type.")

    return pattern


class TableEntry:
    def __init__(self):
        pass


def compile(pattern: Pattern):
    acyclic = eliminate_left_recursion(pattern)
    linear = merge_common_prefix(acyclic)
    # Now you have an acyclic graph. Traverse it to generate table states.
    # State ID
    # input letter -> next TableEntry.
    # Operations
    #   - Call. Add to stack.
    #   - Emit left terminal (precedence). Return.
    #   - Emit right terminal (precedence). Return.
    #   - Match input. Transition to next state.
    states = {}


class TblOperation:
    def __init__(self, next: Optional[int]):
        # None = stay in the same state. Else, index into tbl.
        self.next = next

class TblMatch(TblOperation):
    pass

class TblEmitLeft(TblOperation):
    pass

class TblEmitRight(TblOperation):
    pass

class TblCall(TblOperation):
    pass


# a + b + c
example = Choice(["cat", "car"])
table = [{
        # 0
        "c": TblMatch(1)
    },
    {
        # 1
        "a": TblMatch(2),
    },
    {
        "t": TblEmitRight(-1),
        "r": TblEmitRight(-1),
    }
]

def match(tbl: List[dict], input: str):
    state = 0
    output_queue = []
    pending_stack = []

    for idx, letter in enumerate(input):
        entry = tbl[state].get(letter)
        if entry is None: 
            raise ValueError(f"Mismatch at {idx}: {input[:idx]}\033[4m{input[idx]}\033[0m{input[idx+1:]}")
        elif isinstance(entry, TblMatch):
            print(f"{letter}", end=" ")
            # pending_stack.append(letter)
        elif isinstance(entry, TblEmitRight):
            print(f"{letter}", end=" ")
            # pending_stack.append(letter)
            # TODO.... This needs precedence handling.
            # while pending_stack:
            #     output_queue.append(pending_stack.pop())
        else:
            raise NotImplemented("tbd...")
        
        state = entry.next
        if state == -1:
            if idx < len(input) - 1:
                raise ValueError(f"Input not fully consumed: {idx}: {input[:idx]}, {input[idx]}, {input[idx+1:]}")
        
        
match(table, "bat")

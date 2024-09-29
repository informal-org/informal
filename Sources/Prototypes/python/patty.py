"""
Pattern to table compiler.

Ordered choice between patterns - rather than checking each pattern in order, we compile a lookup table of character -> list of patterns which match in order.
"""
from collections import defaultdict
from typing import List, Union


class Pattern:
    def __init__(self):
        pass


class Choice(Pattern):
    def __init__(self, elements: List[Union[Pattern, str]]):
        self.elements = elements
        super().__init__()

class Sequence(Pattern):
    def __init__(self, elements: List[Union[Pattern, str]]):
        self.elements = elements
        super().__init__()


class Union(Pattern):
    def __init__(self, elements: List[Union[Pattern, str]]):
        self.elements = elements
        super().__init__()


class PatternIterState():
    def __init__(self, pattern, index, visited_nodes):
        self.pattern = pattern
        self.index = index
        self.visited_nodes = visited_nodes


def get_matches(pattern):
    # Given a pattern, yields a list of matched character and remaining pattern.
    # A single pattern could potentially match many things, each of which may
    # have it's own remaining pattern context.
    if pattern:
        yield (pattern[0], pattern[1:])
    yield (PATTERN_TERMINAL, '')


def depth_get_matches(pattern, visited_nodes):
    nodes = visited_nodes.copy()      # Set of visited nodes. Initialize to empty set on base call.
    if pattern:
        # assume pattern contains a sequence of sub-patterns, which may recurse.
        # Look at just the first pattern.
        sub_pattern = pattern[0]
        # if it's terminal, then it's a prefix that may match.
        if isinstance(sub_pattern, str):
            yield (sub_pattern[0], sub_pattern[1:])
        elif sub_pattern not in visited_nodes:
            # Ensure we don't recurse infinitely to the same patterns.
            nodes.append(sub_pattern)   # TODO: Should this append "pattern" or "sub_pattern"
            sub_matches = depth_get_matches(sub_pattern, nodes)
            for match in sub_matches:
                yield match


PATTERN_TERMINAL = "TERMINAL"


def compile(patterns, mode="any"):
    # As implemented, patterns are all choices.
    # character -> ordered list of pattern matches.
    prefix_table = defaultdict(list)
    for current_pattern, base_pattern in patterns:
        if current_pattern:
            # Really, what we want the thing to return is a list of matches.
            for prefix, rest_pattern in get_matches(current_pattern):
                prefix_table[prefix].append((rest_pattern, base_pattern))
        else:
            prefix_table[PATTERN_TERMINAL].append((None, base_pattern))

    # Character -> map of next character -> remaining map.
    compiled_table = {}
    for prefix, prefix_patterns in prefix_table.items():
        if mode == "any":
            # Choose between any of these patterns.
            if prefix == PATTERN_TERMINAL:
                compiled_table[prefix] = [base_pattern for _, base_pattern in prefix_patterns]
            else:
                # Map of next character -> remaining map.
                compiled_table[prefix] = compile(prefix_patterns, mode)
        elif mode == "all":
            # All of the pattern conditions must be met for any given input.
            if len(prefix_patterns) == len(patterns):
                if prefix == PATTERN_TERMINAL:
                    compiled_table[prefix] = [base_pattern for _, base_pattern in prefix_patterns]
                else:
                    compiled_table[prefix] = compile(prefix_patterns, mode)

    return compiled_table


def start_compile(patterns, mode="any"):
    return compile([(p, p) for p in patterns], mode)

# To start with, let's just test a list of strings with no nesting.
print(start_compile(["cat", "car"], mode="all"))
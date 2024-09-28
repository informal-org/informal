"""
Pattern to table compiler.

Ordered choice between patterns - rather than checking each pattern in order, we compile a lookup table of character -> list of patterns which match in order.
"""
from collections import defaultdict


def get_matches(pattern):
    # Given a pattern, yields a list of matched character and remaining pattern.
    if pattern:
        yield (pattern[0], pattern[1:])
    return (PATTERN_TERMINAL, '')


PATTERN_TERMINAL = "TERMINAL"


def compile(patterns):
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
        if prefix == PATTERN_TERMINAL:
            compiled_table[prefix] = [base_pattern for _, base_pattern in prefix_patterns]
        else:
            # Map of next character -> remaining map.
            compiled_table[prefix] = compile(prefix_patterns)

    return compiled_table


def start_compile(patterns):
    return compile([(p, p) for p in patterns])

# To start with, let's just test a list of strings with no nesting.
print(start_compile(["cat", "car", "dog"]))
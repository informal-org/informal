"""
Pattern to table compiler.

Ordered choice between patterns - rather than checking each pattern in order, we compile a lookup table of character -> list of patterns which match in order.
"""
from collections import defaultdict
from typing import List, Union


class Pattern:
    def __init__(self):
        self.initial_state = OrderedState()

    def add_seq(self, seq: str, pattern):
        next_state = None
        for c in seq:
            next_state = OrderedState()
            self.current_state[c] = [next_state]
            self.current_state = next_state
        self.current_state[PATTERN_TERMINAL] = pattern
    
    def add_choice(self, choice: str):
        # Preserve the current state, while merging choice nodes.
        next_state = None
        for c in choice:
            next_state = OrderedState()
            self.current_state[c] = [next_state]
            self.current_state = next_state


class Choice(Pattern):
    def __init__(self, elements: List[Union[Pattern, str]], name=None):
        self.elements = elements
        self.name = name
        super().__init__()

    def __repr__(self):
        return f"{self.name + ' : ' if self.name else ''}Choice({self.elements})"

    def to_state_machine(self, visited):
        # Converts this pattern to a state machine.
        # Visited - set of visited patterns.
        visited.add(self)
        for e in self.elements:
            current_state = State(transitions=dict(), pattern=self)
            if isinstance(e, str):
                for c in e:
                    next_state = State(transitions=dict(), pattern=self)
                    current_state.transitions[c] = next_state
                    current_state = next_state
                current_state.transitions[PATTERN_TERMINAL] = State(transitions=dict(), pattern=self)
            elif isinstance(e, Pattern):
                if e in visited:
                    # This pattern is already visited, so we can just reference it.
                    current_state = e.initial_state
                else:
                    current_state = e.to_state_machine(visited)

            # Merge the choices between the initial state of sub-patterns.
            initial_state.merge(current_state)

        return initial_state
    

class Sequence(Pattern):
    ### Sequence of patterns. Does not support recursion.
    def __init__(self, elements: List[Union[Pattern, str]], name=None):
        self.elements = elements
        self.name = name
        super().__init__()
        

    def __repr__(self):
        return f"{self.name + ' : ' if self.name else ''}Sequence({self.elements})"


# def PrecedenceSeq(Sequence):
#     """
#     Sequence which respects precedence rules in how it recurses.
#     So left hand side will recurse to any lower-priority operators, 
#     and right hand side will recurse to any higher-priority operators.
#     Associtivity determines behavior of equal precedence operators.
#     """
#     def __init__(self, elements: List[Union[Pattern, str]]):
#         super().__init__(elements)


# class LeftSeq(PrecedenceSeq):
#     """
#     Left associative sequence. a + b + c = (a + b) + c. 
#     Left side binds more tightly to equal precedence operators.
#     """
#     def __init__(self, elements: List[Union[Pattern, str]]):
#         self.elements = elements
#         super().__init__()


# class RightSeq(PrecedenceSeq):
#     """
#     Right associative sequence.
#     a = b = c is equivalent to a = (b = c).
#     """
    
#     def __init__(self, elements: List[Union[Pattern, str]]):
#         self.elements = elements
#         super().__init__()

    

class Union(Pattern):
    def __init__(self, elements: List[Union[Pattern, str]], name=None):
        self.elements = elements
        self.name = name
        super().__init__()

    def __repr__(self):
        return f"{self.name + ' : ' if self.name else ''}Union({self.elements})"

class State:
    def __init__(self, transitions, pattern: Pattern = None):
        """
        Transitions are all valid transitions from this current state.
        Represented with a map in python, from input -> next state. 
        In Zig, this can be done with a popcount list for compactness.
        """
        self.transitions = transitions
        self.pattern = pattern


class OrderedState:
    def __init__(self):
        """
        A state diagram representing multiple states combined together.
        """
        self.transitions = defaultdict(list)
    
    def merge(self, other):
        """
        Merge the other states into this states, such that a single lookup can lookup both transitions in order.
        other: Union[State, "OrderedState"]
        """
        pass
        # for k, v in other.transitions.items():
        #     if isinstance(v, State):
        #         self.transitions[k].append((v, other.pattern))
        #     else:
        #         # Ordered state.
        #         self.transitions[k].extend(v)



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


# def enque_explore(node, explore_queue, dependencies):
#     if node not in dependencies:
#         dependencies[node] = []
#         explore_queue.append((node, 0))
#     else:
#         # Already enqueued.
#         return

# def get_explore_nodes(pattern, explore_queue, dependencies):
#     if isinstance(pattern, Sequence):
#         enque_explore(pattern, explore_queue, dependencies)
#     elif isinstance(pattern, str):
#         explore_queue.append((pattern, 0))
#     elif isinstance(pattern, Union) or isinstance(pattern, Choice):
#         # All of the options can be valid roots.
#         for elem in pattern.elements:
#             explore_queue.append((elem, 0))
#             if elem in dependencies
#             dependencies[elem]
#             # if isinstance(e, Pattern):
#             #     dependencies.setdefault(e, []).append((current, i))
#             #     explore_queue.append((e, i))
#     else:
#         raise ValueError("Unknown pattern type.")


def bottom_up_parse(root):
    dependencies = defaultdict(list)   # pattern -> list of refs (pattern, index).
    root_wrapper = Sequence([root])
    explore_queue = [(root_wrapper, 0)]
    
    while explore_queue:
        current_pattern, index = explore_queue.pop(0)
        def pattern_finished():
            # We've reached the end of this sequence.
            # Emit some kind of marker, and continue processing where this is a sub-sequence.
            print(f"End of sequence after { pattern_at } - {current_pattern}")
            other_dependencies = dependencies[current_pattern]
            print(f"Continuing with: {other_dependencies}")
            for elem, elem_index in other_dependencies:
                if elem == current_pattern:
                    # TODO: Any special case here?
                    print("Skipping self.")
                    continue
                if isinstance(elem, Sequence):
                    if elem_index + 1 < len(elem.elements):
                        print(f"TODO explore {elem} at {elem_index + 1}")
                        explore_queue.append((elem, elem_index + 1))
                    else:
                        # That one's done too!
                        print(f"End of sub-sequence: {elem}")
                        other_dependencies += dependencies[elem]
                elif isinstance(elem, Choice):
                    # If any of the options pass, then propagate up.
                    # Union requires all to pass.
                    print(f"Dependency for choice {elem} met.")
                    other_dependencies += dependencies[elem]
                else:
                    raise ValueError(f"Not implemented - pattern type {type(elem)}.")


        if isinstance(current_pattern, Sequence):
            print("Exploring Sequence: ", current_pattern.name, " at ", index)
            pattern_at = current_pattern.elements[index]
            if isinstance(pattern_at, str):
                # We can process this node and continue processing this sequence.
                # TODO: Actual state machine processing.
                print("Matching: ", pattern_at)
                if index + 1 < len(current_pattern.elements):
                    print("Enqueuing next: ", current_pattern, index + 1)
                    explore_queue.append((current_pattern, index + 1))
                else:
                    print("End of sequence: ", current_pattern)
                    pattern_finished()
            else:
                # Welp - must go deeper.
                if pattern_at not in dependencies:
                    explore_queue.append((pattern_at, 0))
                else:
                    # This is a dependency we've already seen.
                    print("Dependency already seen: ", pattern_at.name)
                    
                    if index + 1 < len(current_pattern.elements):
                        print("Enqueuing next: ", current_pattern, index + 1)
                        explore_queue.append((current_pattern, index + 1))
                    else:
                        print("End of sequence: ", current_pattern)
                        pattern_finished()


                # When that dependency finishes, indicate to come back here.
                dependencies[pattern_at].append((current_pattern, index))
        elif isinstance(current_pattern, Union) or isinstance(current_pattern, Choice):
            # All elements are possible roots. Queue them up!
            assert index == 0, "Index should be 0 for Union/Choice."
            print("Exploring Union/Choice: ", current_pattern.elements)
            finished = True
            for sub_index, elem in enumerate(current_pattern.elements):
                if isinstance(elem, str):
                    # TODO: Do something proper with this
                    print("Matching choice str - ", elem)
                else:
                    finished = False
                    if elem not in dependencies:
                        print("Enqueuing: ", elem)
                        # This hasn't been explored yet.
                        explore_queue.append((elem, 0))
                    dependencies[elem].append((current_pattern, sub_index))

            if finished:
                # If all of the things were terminal, then mark this as done.
                pattern_finished()
        else:
            # Patterns with strings should not end up here.
            # It should be part of some higher-level pattern.
            raise ValueError(f"Unknown pattern type - {current_pattern} - {type(current_pattern)}.")


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
# print(start_compile(["cat", "car"], mode="all"))

term = Choice(["a", "b", "c"], name="term")
expr = Choice([], name="expr")
expr.elements = [Sequence([expr, "+", term], name="expr + term"), term]
bottom_up_parse(expr)
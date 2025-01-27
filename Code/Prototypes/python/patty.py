"""
Pattern to table compiler.

Ordered choice between patterns - rather than checking each pattern in order, we compile a lookup table of character -> list of patterns which match in order.
"""
from collections import defaultdict
from typing import Dict, List, Set, Union, Optional


class Pattern:
    def __init__(self):
        self.initial_state = OrderedState()
        self.state = None

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


class Literal(Pattern):
    def __init__(self, value: str):
        self.value = value
        super().__init__()

    def __repr__(self):
        return self.value


class Choice(Pattern):
    def __init__(self, elements: List[Pattern], name=None):
        self.elements = elements
        self.name = name
        super().__init__()

    def __repr__(self):
        return f"{self.name if self.name else ' | '.join([str(e) for e in self.elements])}"

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
        return f"{self.name + ' = ' if self.name else ''}{', '.join([str(e) for e in self.elements])}"
    
    def str(self):
        return f"{self.name if self.name else ', '.join([str(e) for e in self.elements])}"


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

    

# class Union(Pattern):
#     def __init__(self, elements: List[Union[Pattern, str]], name=None):
#         self.elements = elements
#         self.name = name
#         super().__init__()
#
#     def __repr__(self):
#         return f"{self.name + ' : ' if self.name else ''}Union({self.elements})"


class State:
    def __init__(self, state_id, transitions):
        """
        Transitions are all valid transitions from this current state.
        Represented with a map in python, from input -> next state. 
        In Zig, this can be done with a popcount list for compactness.
        """
        self.state_id = state_id
        self.transitions = transitions


class Transition:
    """
    What to do for a given input. Should always contain a goto state.
    May also contain other actions, and action-related parameters.
    """
    def __init__(self, next_state, pattern: Optional[Pattern] = None):
        self.next_state = next_state    # ID or reference to the next state.
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
    initial_root_wrapper = Sequence([root])
    explore_queue = [(initial_root_wrapper, 0)]

    def pattern_finished(terminated_pattern):
        # We've reached the end of this sequence.
        # Emit some kind of marker, and continue processing where this is a sub-sequence.
        # TODO: Should this be cleared out for choices as well or maintained until all choice nodes are done?
        other_dependencies = dependencies[terminated_pattern].copy()
        dependencies[terminated_pattern] = []
        # Is this equivalent to just adding other deps to explore queue?
        for elem, elem_index in other_dependencies:
            if isinstance(elem, Sequence):
                if elem_index + 1 < len(elem.elements):
                    explore_queue.append((elem, elem_index + 1))
                else:
                    # That one's done too!
                    pattern_finished(elem)
            elif isinstance(elem, Choice):
                # If any of the options pass, then propagate up.
                # Union requires all to pass.
                other_dependencies += dependencies[elem]
                dependencies[elem] = []
            else:
                raise ValueError(f"Not implemented - pattern type {type(elem)}.")
            
    def enqueue_explore(elem, index):
        if isinstance(elem, Sequence):
            if index + 1 < len(elem.elements):
                explore_queue.append((elem, index + 1))
            else:
                pattern_finished(elem)
        elif isinstance(elem, Choice):
            assert index == 0, "Index should be 0 for Choice."
            pass    # TODO
        else:
            raise ValueError(f"Not implemented - pattern type {type(elem)}.")
    
    while explore_queue:
        current_pattern, index = explore_queue.pop(0)

        if isinstance(current_pattern, Sequence):
            print("Exploring Sequence: ", current_pattern, " at ", index)
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
                    pattern_finished(current_pattern)
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
                        pattern_finished(current_pattern)


                # When that dependency finishes, indicate to come back here.
                dependencies[pattern_at].append((current_pattern, index))
        elif isinstance(current_pattern, Choice):
            # All elements are possible roots. Queue them up!
            assert index == 0, "Index should be 0 for Union/Choice."
            print("Exploring Union/Choice: ", current_pattern)
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
                pattern_finished(current_pattern)
        else:
            # Patterns with strings should not end up here.
            # It should be part of some higher-level pattern.
            raise ValueError(f"Unknown pattern type - {current_pattern} - {type(current_pattern)}.")


def gen_state_machine(root: Pattern):
    # List of States. Index = ID. Each state goes from a given input -> Transition.
    states = []
    def new_state():
        state = State(state_id=len(states), transitions=dict())
        states.append(state)
        return state


    dependencies = defaultdict(list)    # pattern -> list of unvisited references (pattern, index of ref).
    initial_root_wrapper = Sequence([root])
    explore_queue = []

    def enqueue(pattern, index):
        pattern_at = pattern.elements[index]
        if pattern_at not in dependencies:
            # If this pattern isn't already in the queue (i.e. something else isn't awaiting it), add it.
            explore_queue.append((pattern, index))
            if pattern_at.state is None:
                pattern_at.state = new_state()

            # When pattern at finishes, go to the next state.
            dependencies[pattern_at].append((pattern, index))
        else:
            # This might be in the queue or already done...
            if not dependencies[pattern_at]:
                # Already done - consider it met.
                advance(pattern, index)
            else:
                dependencies[pattern_at].append((pattern, index))


    def terminate(pattern):
        print("terminate: ", pattern)
        # This pattern has been met.
        # Advance any patterns waiting on this one.
        pattern_deps = dependencies[pattern].copy()     # TODO: This copy seems unnecessary.
        dependencies[pattern] = []
        for dep_pattern, dep_index in pattern_deps:
            advance(dep_pattern, dep_index)

    def advance(pattern, index):
        # When some sub-pattern finishes, we advance any dependent patterns which were waiting on it.
        # Which entails, enqueueing the next input if it's not terminal.
        # If it terminates, this sub-pattern has been met as well. Advance its dependencies.
        if isinstance(pattern, Sequence):
            if index + 1 < len(pattern.elements):
                enqueue(pattern, index + 1)
            else:
                terminate(pattern)
        elif isinstance(pattern, Choice):
            # One option of a choice has been met.
            # Advance everything waiting on this choice if any option passes. The full state machine isn't known, but
            # we have a placeholder state ID for this. For union, we may need to wait on all to pass.
            terminate(pattern)
        elif isinstance(pattern, Literal):
            # Literals always immediately terminate.
            terminate(pattern)

    def visit(pattern, index=0):
        assert index < len(pattern.elements), f"Index {index} out of bounds {len(pattern.elements)} for {pattern}."
        pattern_at = pattern.elements[index]
        print("visit: ", pattern_at)
        if isinstance(pattern_at, Literal):
            terminate(pattern_at)
        elif isinstance(pattern_at, Sequence):
            enqueue(pattern_at, 0)
        elif isinstance(pattern_at, Choice):
            for i in range(len(pattern_at.elements)):
                enqueue(pattern_at, i)

    # Explore

    enqueue(initial_root_wrapper, 0)
    while explore_queue:
        # Elements in the explore queue have their dependencies already met.
        # We can advance them to their next states.
        current_pattern, index = explore_queue.pop(0)
        visit(current_pattern, index)

    print("States: ", states)
    # All dependencies should be met at the end.
    for dep, remaining in dependencies.items():
        if remaining:
            print("Unmet dependency! ", dep, remaining)


def top_down_parser(root: Pattern, visited: Dict[Pattern, int], states: List[State]):
    # Loop over the pattern. If it's a sequence, we chain the patterns together. If it's a choice, we merge the sub-patterns.
    # Handle recursion. Left-recursion should point back to that pattern's State ID and have some behavior when it terminates.
    if root in visited:
        # TODO: Handle recursion.
        pass

ACTION_EMIT = "emit"
ACTION_PUSH = "push"
ACTION_POP = "pop"

STATE_TERMINAL = "TERMINAL"


class TopDownParser:
    def __init__(self):
        self.visited = {}   # Pattern -> State ID
        self.states = []

    def new_state(self):
        state = State(state_id=len(self.states), transitions=dict())
        self.states.append(state)
        return state
    
    def merge(self, state, other, pending_state_action=None, pending_other_action=None):
        # If they share a key and both go to the same state, keep as is.
        # If they go to different states, then merge those states and go there instead.
        # That old state is potentially dangling now.
        if state == STATE_TERMINAL:
            pass
        
        if other == STATE_TERMINAL:
            pass

        for key, (next_state, action) in other.transitions.items():
            if key in state.transitions:
                state_transition, state_action = state.transitions[key]
                if state_transition == next_state:
                    if state_action != action:
                        raise ValueError(f"Conflicting actions {state_action} != {action} for {key}.")
                    # Already merged.
                    continue
                else:
                    if state_action != action:
                        # IDK what to do here...
                        # Likely need to push down the action context to the merge, and have it perform that appropriately.
                        raise NotImplementedError(f"Conflicting actions during merge {state_action} != {action} for {key}.")
                    state.transitions[key] = (self.merge(state_transition, next_state), state_action)

    def chain(self, state, next_state):
        # Find all terminal-endpoints for this state, and set them to transition to the next state.
        if state.transitions:
            for key, (next_state, action) in state.transitions.items():
                if next_state == STATE_TERMINAL:
                    state.transitions[key] = (next_state, action)
            return state
        else:
            return self.merge(state, next_state)
        
    
    def visit(self, pattern):
        if pattern in self.visited:
            # TODO: Handle recursion.
            # It should kinda return that State ID.
            pass
        
        state = self.new_state()  # Start state.
        self.visited[pattern] = state.state_id
        terminals = [state]

        if isinstance(pattern, Sequence):
            for elem in pattern.elements:
                if isinstance(elem, Literal):
                    elem_state = self.new_state()
                    elem_state.transitions[elem.value] = (STATE_TERMINAL, ACTION_EMIT)   # Likely something in the future to indicate what to emit.
                    self.chain(state, elem_state)
                elif isinstance(elem, Sequence):
                    next_state, next_terminals = self.visit(elem)
                    terminals = self.chain(terminals, next_state)
                elif isinstance(elem, Choice):
                    next_states = self.visit(elem)
                    for state in next_states:
                        pass
            # TODO: Add in an action_emit for the sequence itself here.
        elif isinstance(pattern, Choice):
            # It should return this list of terminals.
            # If previous was a sequence, then it needs to chain each of them.
            terminals = []
            for elem in pattern.elements:
                elem_state = self.new_state()
                if isinstance(elem, Literal):
                    next_state = self.new_state()
                    elem_state.transitions[elem.value] = next_state
                    self.merge(state, elem_state)
                    terminals.append(next_state)
                elif isinstance(elem, Sequence):
                    # Construct a sub-graph for that sequence.
                    end_state = self.visit(elem, elem_state.state_id)
                    self.merge(state, elem_state)
                    terminals.append(end_state)
                elif isinstance(elem, Choice):
                    end_state = self.visit(elem, elem_state.state_id)
                    self.merge(state, elem_state)
                    terminals.append(end_state)
                else:
                    raise ValueError(f"Unknown pattern type {type(elem)}.")
            

            elem_state = self.visit(elem, state.state_id)
            





"""
Test case: a + b * c
Expected result: a b c * +
State ID -> (transition, action)
0: 
   abc: (1, emit)
1:
   +: (2, push)
   *: (5, emit)    -- emit immedietly since we recognize it as the highest precedence. AND left associative.
   eof: (_, end)   -- after an operator or with just a number.
2:  
    -- Ops with lower or equal precedence than + should cause a pop - which DOES NOT advance the input cursor.
    abc: (3, emit)
3:
    -- Ops with lower or equal precedence than + should cause a pop - which DOES NOT advance the input cursor.
    +: (4, pop)
    *: (5, emit)
4:
    -- You get to this state when popping +. The states observed here are the stack states. Pop everything lower or equal.
    +: (4, pop)
    *: (3, _)   -- return back on any higher precedence.
5:  -- Right hand side after *
    abc: (1, emit)

   
Intuition:
When it's at an operator, we queue it up until we see the next operator with lower precedence
    meaning this should be done before that operator.
Pushes need to remember not just the operator but where in the input that was from to differentiate multiple instances of the same op.
Pop should not advance the input - giving you a chance to pop repeatedly.
We need to either be able to look at the top of the stack OR get some kind of state context from what's on the stack - i.e. pop makes it transition to something from the stack.
    OR the state associated with POP makes it look at the stack as the input instead, allowing it to decide from that context.
    Then when it's done, you advance to the next input which continues with input handling - likely back to the state it was in.

    
---
Approach:
    Merged states represent an overlap of various states. We need to match without backtracking, and since the state machine is built incrementally, 
    we have to store some placeholders to indicate merge-points. Where they begin and where each of the merged states end.
    When you then add a new sequence to it, it has to append it by merging it where both paths left-off.
    If the sequence loops around, you merge it by tiling it until it repeats. And looping at that point back to a known previous state.
        You recognize it at each merge start and end points to see if the other paths are at some known previous state.
        This analysis has to see how much input is consumed in each path, which should exclude stack-pops which don't act on the input.

"""



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

term = Choice([Literal("a"), Literal("b"), Literal("c")], name="term")
expr = Choice([], name="expr")
expr.elements = [Sequence([expr, Literal("+"), term], name="expr + term"), term]
# bottom_up_parse(expr)
gen_state_machine(expr)
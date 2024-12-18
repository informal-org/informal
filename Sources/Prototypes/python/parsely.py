"""
A parse table generator.
Each pattern is independent, with a start state, a successful end state and a failure state. All branching is handled internally, and ultimately terminates at these states.
These start and end states are redundant, but simplifies the implementation. They consume no input and can be eliminated in later passes.

Sequences chain their success states with some append operator to go from one node's success state to the next node's start state.
    If there's multiple input paths, then the start node pushes some context to the stack and the end-node pops it to know which path to take.
Choices merge states. Any non-overlapping states are direct transitions.
    You first compile all of the sub-patterns. If multiple choice nodes overlap for the first input, branch while pushing some context to the stack. 
    Any failure states would then backtrack to the next path. 
    A post-processing pass can then eliminate this backtracking altogether by creating additional states based on what's known at each failure point and jump to the appropriate next-state.
"""

from enum import Enum


STATE_ID = 0

class StateType(Enum):
    START = 0    # Always pushes to the context stack
    SUCCESS = 1  # Always does a peek of the context stack and branches.
    FAILURE = 2  # Peeks the context stack and branches based on it.
    CHOICE = 3   # Snapshots the current state so it can be restored.
    PUSH = 4
    POP = 5



class State:
    def __init__(self, state_type, pattern):
        self.id = STATE_ID
        STATE_ID += 1
        self.state_type = state_type
        self.pattern = pattern
        # List of states which reference this state.
        self.referenced_by = {}
        # From some input / context -> what state to transition to.
        self.transitions = {}

    def add_transition(self, input_ctx, state):
        assert input_ctx not in self.transitions, f"Transition already exists for {input_ctx} in {self}"
        self.transitions[input_ctx] = state
        state.add_reference(input_ctx, self)

    def add_reference(self, context, state):
        assert context not in self.referenced_by, f"Reference already exists for {context} in {self}"
        self.referenced_by[context] = state
    
    def __repr__(self):
        return f"State({self.state_type}, {self.pattern})"
    


class Pattern:
    def __init__(self):
        self.start = State(StateType.START, self)
        self.failure = State(StateType.FAILURE, self)
        self.success = State(StateType.SUCCESS, self)

class Literal(Pattern):
    def __init__(self, value: str):
        self.value = value
        super().__init__()

    def __repr__(self):
        return self.value

class Choice(Pattern):
    def __init__(self, patterns: list[Pattern]):
        self.patterns = patterns
        super().__init__()

    def __repr__(self):
        return f"Choice({self.patterns})"


class Sequence(Pattern):
    def __init__(self, patterns: list[Pattern]):
        self.patterns = patterns
        super().__init__()

    def __repr__(self):
        return f"Sequence({self.patterns})"


def chain(context, left, right):
    """
    Sequences chain their success states with some append operator to go from one node's success state to the next node's start state.

    Context - Reference to the unique context from which the left-node was called to differentiate multiple paths.
              Choices create separate paths, which are these contexts.
              The context does not matter for what happens within a state sub-graph. Just branches where it might go afterwards.
    """
    left.success.add_transition(context, right.start)


def branch(choice_pattern, option):
    context = State(state_type=StateType.CHOICE, pattern=choice_pattern)
    choice_pattern.start.add_transition(context, option.start)
    option.success.add_transition(context, choice_pattern.end)
    option.failure.add_transition(context, choice_pattern.failure)
    # That choice pattern failure should then backtrack to the next option.
    return context


class Builder:
    def __init__(self):
        self.visited = {}


    def start_build(self, root):
        # Root context is a choice of one option.
        root_context = State(StateType.CHOICE, root)
        self.build(root, root_context)

    def build(self, root, context):
        if root in self.visited:
            pass

        if isinstance(root, Literal):
            # Basically a sequence. 
            current_state = root.start
            for c in root.value:
                current_state = current_state.add_transition()

            

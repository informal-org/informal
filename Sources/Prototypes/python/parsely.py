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

Actions are defined on the state (like a moore machine), not by the transition. You can perform an action on the input or on the context stack.
Each transition matches by the current input cursor and by the top of the context stack. The state action is performed before any transition.
"""

from collections import defaultdict
from enum import Enum
from dataclasses import dataclass


STATE_ID = 0


# Input action is done before context action.
# Actions are done before any transitions.
class InputAction(Enum):
    NONE = 0
    ADVANCE = 1        # Advance the cursor to the next character.
    EMIT_ADVANCE = 2   # Emit to output and advance the cursor.
    SEEK = 3           # Backtrack to a previous checkpoint.


class ContextAction(Enum):
    NONE = 0
    PUSH = 1             # Snapshot the current state. When you enter a sub-pattern or choice.
    POP = 2              # Pop and discard.
    POP_EMIT = 3
    POP_JUMP_SUCCESS = 4 
    POP_JUMP_FAILURE = 5   # Backtrack to the next option. Discard the current option context.


PATTERN_ANY = "ANY"
PATTERN_END = "END"  # End of stack / end of input.

@dataclass
class Transition:
    context_pattern = PATTERN_ANY
    input_pattern = PATTERN_ANY


@dataclass
class Action:
    input: InputAction = InputAction.NONE
    context: ContextAction = ContextAction.NONE


class State:
    def __init__(self, pattern, action):
        self.id = STATE_ID
        STATE_ID += 1
        self.pattern = pattern
        self.action = action
        # List of states which reference this state.
        self.referenced_by = set()
        # Unconditional next-state. Used in start / success / failure sometimes.
        self.next_state = None
        # From pattern -> state. As two layer dict (context, input) -> state.
        self.transitions = defaultdict(lambda: defaultdict(lambda: None))

    def add_transition(self, transition, state):
        assert self.transitions[transition.context_pattern][transition.input_pattern] is None, f"Transition already exists for {transition} in {self}"
        self.transitions[transition.context_pattern][transition.input_pattern] = state
        state.add_reference(state)

    def add_reference(self, state):
        self.referenced_by.add(state)
    
    def __repr__(self):
        return f"State({self.state_type}, {self.pattern})"
    


class Pattern:
    def __init__(self):
        self.start = State(self, Action(context=ContextAction.PUSH))
        self.failure = State(self, Action(context=ContextAction.POP_JUMP_FAILURE))
        self.success = State(self, Action(context=ContextAction.POP_EMIT))

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
    left.success.add_transition(Transition(context, PATTERN_ANY), right.start)


def branch(choice_pattern):
    """
    Choices are sequentially evaluated in the initial backtracking version.
    One option's failure leads to the next option's start. 
    The branch root branches to the first option's start.
    The final option's failure leads to the choice pattern's failure.
    """
    options = choice_pattern.patterns
    assert len(options) >= 2, "No options in choice"  # Must have atleast two options.

    # Create a start and end state for each option.
    option_starts = []
    option_fails = []
    for option in options:
        option_start = State(pattern=option, action=Action(context=ContextAction.PUSH))
        option_success = State(pattern=options[i], action=Action(context=ContextAction.POP_EMIT))
        option_success.add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), choice_pattern.success)
        option_fail = State(pattern=option, action=Action(context=ContextAction.POP_JUMP_FAILURE))
        option.failure.add_transition(Transition(context=option_start.id, input=PATTERN_ANY), option_fail)
        option.success.add_transition(Transition(context=option_start.id, input=PATTERN_ANY), option_success)
        option_start.add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), option.start)
        build(option)

        option_starts.append(option_start)
        option_fails.append(option_fail)

    # Start with the first option. 
    choice_pattern.start.add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), option_starts[0])

    # Chain the options together so that the first option's failure leads to the next option's start.
    for i in range(len(options) - 1):
        option_fails[i].add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), option_starts[i + 1])

    # The final option's failure leads to the choice pattern's failure.
    option_fails[-1].add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), choice_pattern.failure)
    


def build(pattern):
    pass


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

            

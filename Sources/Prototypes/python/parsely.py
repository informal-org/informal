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
import logging

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger("parsely")

STATE_ID = 0
ALL_STATES = []


# Input action is done before context action.
# Actions are done before any transitions.
class InputAction(Enum):
    NONE = 0
    ADVANCE = 1        # Advance the cursor to the next character.
    EMIT_ADVANCE = 2   # Emit to output and advance the cursor.
    SEEK = 3           # Backtrack to a previous checkpoint.

    def __str__(self):
        return self.name


class ContextAction(Enum):
    NONE = 0
    PUSH = 1             # Snapshot the current state. When you enter a sub-pattern or choice.
    POP = 2              # Pop and discard.
    POP_EMIT = 3
    POP_JUMP_SUCCESS = 4 
    POP_JUMP_FAILURE = 5   # Backtrack to the next option. Discard the current option context.
    POP_PUSH = 6           # Pop and discard the current context, then push the next context.

    def __str__(self):
        return self.name


PATTERN_ANY = "ANY"
PATTERN_DEFAULT = "DEFAULT"   # Like any, but matches only if other patterns fail to match.
PATTERN_END = "END"  # End of stack / end of input.

@dataclass
class Transition:
    context: str = PATTERN_DEFAULT
    input: str = PATTERN_DEFAULT

    def __str__(self):
        return f"Transition({self.context}, {self.input})"


@dataclass
class Action:
    input: InputAction = InputAction.NONE
    context: ContextAction = ContextAction.NONE

    def __str__(self):
        return f"Action({self.input}, {self.context})"


class State:
    def __init__(self, pattern, action):
        global STATE_ID
        global ALL_STATES
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
        ALL_STATES.append(self)

    def add_transition(self, transition, state):
        assert self.transitions[transition.context][transition.input] is None, f"Transition already exists for {transition} in {self}"
        self.transitions[transition.context][transition.input] = state
        state.add_reference(state)

    def add_reference(self, state):
        self.referenced_by.add(state)
    
    def __repr__(self):
        return f"State({self.id}, {self.pattern})"
    


class Pattern:
    def __init__(self):
        self.start = State(self, Action(context=ContextAction.PUSH))
        self.failure = State(self, Action(context=ContextAction.POP_JUMP_FAILURE))
        self.success = State(self, Action(context=ContextAction.POP_EMIT))

    def __str__(self):
        return f"Pattern({self.start.id})"
    
    def __repr__(self):
        return f"Pattern({self.start.id})"

class Literal(Pattern):
    def __init__(self, value: str):
        self.value = value
        super().__init__()

    def __str__(self):
        return f"Literal({self.value})"
    
    def __repr__(self):
        return f"Literal({self.value})"
    
class Any(Pattern):
    def __init__(self, terminals: list):
        self.terminals = terminals   # List of characters which terminate this pattern and starts the next one.
        super().__init__()

    def __str__(self):
        return f"Any()"
    
    def __repr__(self):
        return f"Any()"

class Choice(Pattern):
    def __init__(self, patterns: list[Pattern]):
        self.patterns = patterns
        super().__init__()

    def __str__(self):
        return f"Choice({self.patterns})"
    
    def __repr__(self):
        return f"Choice({self.patterns})"


class Sequence(Pattern):
    def __init__(self, patterns: list[Pattern]):
        self.patterns = patterns
        super().__init__()

    def __str__(self):
        return f"Sequence({self.patterns})"
    
    def __repr__(self):
        return f"Sequence({self.patterns})"



class Builder:
    def __init__(self):
        self.visited = set()

    def chain(self, sequence):
        """
        Sequences chain their success states with some append operator to go from one node's success state to the next node's start state.
        Since each state is independent, context differentiates the paths / usages to determine where to go next. 
        A node may appear multiple times in the same sequence, so the context must maintain that index as well.
        The simplest way to do this is just with some extraneous states in between (rather than maintaining more complex contexts which change).
        """

        current_state = sequence.patterns[0]
        first_node = State(pattern=sequence.patterns[0], action=Action(context=ContextAction.PUSH))
        sequence.start.add_transition(
            Transition(context=PATTERN_ANY, input=PATTERN_ANY),
            first_node
        )
        first_node.add_transition(
            Transition(context=PATTERN_ANY, input=PATTERN_ANY),
            current_state.start
        )
        context_node = first_node
        self.build(current_state)

        for elem in sequence.patterns[1:]:
            next_context = State(pattern=elem, action=Action(context=ContextAction.POP_PUSH))
            current_state.success.add_transition(
                Transition(context=context_node.id, input=PATTERN_ANY),
                next_context
            )
            current_state.failure.add_transition(
                Transition(context=context_node.id, input=PATTERN_ANY),
                sequence.failure
            )
            self.build(elem)
            next_context.add_transition(
                Transition(context=PATTERN_ANY, input=PATTERN_ANY),
                elem.start
            )
            current_state = elem
            context_node = next_context

        current_state.success.add_transition(
            Transition(context=context_node.id, input=PATTERN_ANY),
            sequence.success
        )


    def branch(self, choice_pattern):
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
            # Create wrapper states for each option which maintains this branch's context.
            option_start = State(pattern=option, action=Action(context=ContextAction.PUSH))
            option_start.add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), option.start)
            
            option_success = State(pattern=option, action=Action(context=ContextAction.POP_EMIT))
            option.success.add_transition(Transition(context=option_start.id, input=PATTERN_ANY), option_success)
            option_success.add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), choice_pattern.success)

            option_fail = State(pattern=option, action=Action())
            option.failure.add_transition(Transition(context=option_start.id, input=PATTERN_ANY), option_fail)
            
            self.build(option)

            option_starts.append(option_start)
            option_fails.append(option_fail)

        # Start with the first option. 
        choice_pattern.start.add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), option_starts[0])

        # Chain the options together so that the first option's failure leads to the next option's start.
        for i in range(len(options) - 1):
            option_fails[i].add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), option_starts[i + 1])

        # The final option's failure leads to the choice pattern's failure.
        option_fails[-1].add_transition(Transition(context=PATTERN_ANY, input=PATTERN_ANY), choice_pattern.failure)

    def build(self, root):
        if root in self.visited:
            return
        
        self.visited.add(root)
        if isinstance(root, Literal):
            # Basically a sequence. 
            current_state = root.start
            for c in root.value:
                next_state = State(root, Action(input=InputAction.ADVANCE))
                current_state.add_transition(
                    Transition(context=PATTERN_ANY, input=c),
                    next_state
                )
                current_state.add_transition(
                    Transition(context=PATTERN_DEFAULT, input=PATTERN_DEFAULT),
                    root.failure
                )
                current_state = next_state
            current_state.add_transition(
                Transition(context=PATTERN_ANY, input=PATTERN_ANY),
                root.success
            )
        elif isinstance(root, Any):
            start_state = root.start
            start_state.add_transition(
                Transition(context=PATTERN_ANY, input=PATTERN_ANY),
                any_state
            )
            any_state = State(root, Action())  # TODO: action should advance input somehow but only after matching.
            for terminal in root.terminals:
                # Terminate successfully when you see any of the terminal characters.
                start_state.add_transition(
                    Transition(context=PATTERN_ANY, input=terminal),
                    root.success
                )
            # Loop back to the same state on any non-terminal characters.
            start_state.add_transition(
                Transition(context=PATTERN_ANY, input=PATTERN_DEFAULT),
                any_state
            )
        elif isinstance(root, Sequence):
            self.chain(root)
        elif isinstance(root, Choice):
            self.branch(root)
        else:
            raise ValueError(f"Unknown pattern type: {type(root)}")
        

    def print_states(self, root):
        for state in ALL_STATES:
            print(state.id, state.pattern, state.action)
            # Print the nested dictionary of transitions
            for context_pattern, input_patterns in state.transitions.items():
                for input_pattern, next_state in input_patterns.items():
                    print(f"    {context_pattern} -> {input_pattern} -> {next_state.id}")

        print("Start: ", root.start.id)
        print("Success: ", root.success.id)
        print("Failure: ", root.failure.id)


        


def parse(root, input):
    logger.debug("----")
    state = root.start
    stack = []
    cursor = 0
    output = []

    current_char = input[cursor] if cursor < len(input) else PATTERN_END
    current_context = stack[-1]['state'].id if stack else PATTERN_DEFAULT

    while True:
        logger.debug(f"State: {state.id}\t Action: {state.action}\t Input: {current_char}\t StackTop: {current_context}")
        
        # Input actions are done first.
        if state.action.input == InputAction.ADVANCE:
            cursor += 1
        elif state.action.input == InputAction.EMIT_ADVANCE:
            logger.debug("EmitAdvance: ", input[cursor])
            output.append(input[cursor])
            cursor += 1
        elif state.action.input == InputAction.SEEK:
            # Backtrack
            stack_top = stack[-1]
            logger.debug("Seeking to %s", stack_top)
            cursor = stack_top.get('cursor')
        elif state.action.input == InputAction.NONE:
            pass
        else:
            raise ValueError(f"Unknown input action: {state.action.input}")
        
        # Do the context action.
        if state.action.context == ContextAction.PUSH:
            stack.append({
                'cursor': cursor,
                'state': state
            })
        elif state.action.context == ContextAction.POP_EMIT:
            if stack:
                stack_top = stack.pop()
                out = {
                    'cursor_start': stack_top['cursor'],
                    'cursor_end': cursor,
                    'state': stack_top['state']
                }
                logger.debug("Pop Emit: %s", out)
                if cursor < len(input):
                    logger.debug('Output: %s', input[out['cursor_start']:out['cursor_end']])
                output.append(out)
            else:
                raise ValueError("No stack to pop - pop_emit")
        elif state.action.context == ContextAction.POP_JUMP_SUCCESS:
            if stack:
                stack_top = stack.pop()
                state = stack_top['state'].success
            else:
                raise ValueError("No stack to pop - pop_jump_success")
        elif state.action.context == ContextAction.POP_JUMP_FAILURE:
            if stack:
                stack_top = stack.pop()
                state = stack_top['state'].pattern.failure
            else:
                raise ValueError("No stack to pop - pop_jump_failure")
        elif state.action.context == ContextAction.POP_PUSH:
            if stack:
                stack.pop()
                stack.append({
                    'cursor': cursor,
                    'state': state
                })
            else:
                raise ValueError("No stack to pop - pop_push")
        elif state.action.context == ContextAction.NONE:
            pass
        else:
            raise ValueError(f"Unknown context action: {stack.action.context}")


        # Try specific transitions first, then fallback to default patterns
        current_char = input[cursor] if cursor < len(input) else PATTERN_END
        current_context = stack[-1]['state'].id if stack else PATTERN_DEFAULT
        next_state = None
        
        context_transitions = state.transitions.get(
            current_context, 
            state.transitions.get(
                PATTERN_ANY, 
                state.transitions.get(
                    PATTERN_DEFAULT,
                    {}
                )
            )
        )
        if context_transitions:
            next_state = context_transitions.get(current_char, context_transitions.get(PATTERN_ANY, context_transitions.get(PATTERN_DEFAULT, None)))
            if next_state is None:
                logger.debug(f"No next state found for context {current_context} and input {current_char} in state {state.id}")
                next_state = state.pattern.failure
        else:
            logger.debug(f"No transitions found for context {current_context} and input {current_char} in state {state.id}")
            next_state = state.pattern.failure
        

        state = next_state

        # Check for end conditions. TODO
        # if cursor >= len(input) and not stack:
        #     return True, ''.join(output)

        if state == root.success:
            logger.debug("Success: %s", output)
            logger.debug("Input remaining: %s", cursor < len(input))
            return True, output
        elif state == root.failure:
            logger.debug("Failure: %s", output)
            return False, output

            
# pattern = Sequence([Literal("hello"), Literal("world")])
# pattern = Choice([Literal("hello"), Literal("world")])
# builder = Builder()
# builder.build(pattern)
# builder.print_states()
# print("Start: ", pattern.start.id)
# print("Success: ", pattern.success.id)
# print("Failure: ", pattern.failure.id)

# print(parse(pattern, "hello world"))



# declaration = Sequence([
#     Any([":"]), Literal(":"), Any("\n")
# ])

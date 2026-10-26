# Overall flow
Parser:
  -> Parsed Queue of Tokens in postfix order
  -> Kind Counts

Lowering
  -> Parsed Queue -> IR Queue
  IR Tokens Grouped by Kind
  The program structure is gone
  Iterate over parsed queue:
    Literal -> emit Kind (push stack)
    Operator -> emit Binary (pop operands from stack. Push result op to stack)
    Block End -> Emit Block
      start state, current cursor
    End -> IR Exit

DependencyMap
  -> Walks blocks with block iter
    Links per-block elements to each other & block inputs / outputs to reconstruct structure from data dependencies.

Sequencer
  -> Blocks / Dependencies -> Layer of nodes

Regalloc -> Layers -> Registers and resolved ops

CodeGen
  -> IR Queue -> ARM ASM

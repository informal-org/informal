Install dependencies
mix deps get

Start server
mix phx.server

Debugger:
iex -S mix

Schema
    Cell
    - (user)
#   - parent - cell
    - pre_offset - int - Count of cells before this one that's "empty".
    - previous - cell
    - next - cell

#   - children: list or reference to first.
#   - head, tail - no need, can just search for previous = null or next = null.

    - uuid
    - input - string
    - parsed - json
    - output - json
    - id - 
    - dependencies - list of 

Create ecto migrations
mix phx.gen.schema Cell cells name:string uuid:uuid input:string parsed:map output:map dependencies:array:uuid pre_offset:integer previous:uuid next:uuid

Apply migration
mix ecto.migrate



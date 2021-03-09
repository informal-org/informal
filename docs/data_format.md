Contains a representation of the code that can be used for execution. 
The format would be exposed to the user, so consider it vulnerable. 
On the backend, before execution, it gets annotated with author and owner information for billing and permissions.
Code contains the individual cells of execution. 

Cell
    - Data type: auto, str, int, float, bool, binary? unsigned?
    - Structure types: List, map, set
    - Expression types: function definition, variable reference, function reference, function call, expression, objects?
    - null

Will we have objects?
Are function reference and variable reference the same?
How to differentiate a function call

Inline expressions will use the dereferenced ID of the object, not the raw name 

Is pattern matching, method overloading and multiple dispatch a good idea or bad?

Is all of this type annotation in the schema useful? 
Why not just put 1 or 1.5 or "hello" in it directly?
It's kind of represented in json already without this additional field. 

Let's say the type field is optional unless its explicitly defined. 
For most unambiguous things, leave it as is. 
Only define it if say the value is "1.1" and the type is str. 
Why not just make it str automatically then? 

There's the representation of data necessary for the execution of the code and then there's additional information which is formatting and UI only needed by the frontend. i.e. expanded, collapsed, etc.

Let's start without it and only add it if I need to. 

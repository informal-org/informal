# February 2024

## Feb 03
In the past week, built out a table-driven parser in Zig. It uses a fairly compact low-level representation of a state-machine using a bitset to specify which characters match, and popcount to find state transitions. The state machine supports operations such as push and pop onto a secondary stack, allowing it to parse things like precedence efficiently. 
The idea was to write a table generator from a language grammar into this format, emit the table as a CSV file, write hardcode in a table for parsing CSV files. Thus, the grammar would be full encoded in a file which can be read by both the bootstrapping language and by early versions of Informal which would only need to implement the parsing engine to run the table. That allows you to bootstrap the language more easily by splitting up grammar -> table and table -> ast steps.
Decided to pivot away from this approach after figuring out a way to make macros elegantly handle operators and all syntactic blocks. This leads to a much simpler core language with greater flexibily. Since it doesn't need any of the low-level capabilities of Zig, I'm reviving an earlier draft of the language in JS/TS to bootstrap the language faster.

## Feb 10
Got the revived language in a working state with tests passing. The test-suite of expressions built out previously was invaluable in getting this back up and running. 

## Feb 17
Started this devlog proper while adding in notes from the past two weeks. Figured out some more of the details with bootstrapping the language:
    
Exposing scope as an immutable map, so macros can manage the namespace while having language-level consistency on the lifetime of variables.

Subtle tweaking of for loops to allow it to hold onto some state between iteration, retaining the core benefits of immutability with more of the ergonomics of some imperative algorithms.
    ```
    counter = 0
    counter = for x in arr:
        counter = counter + 1
    ```
Variables defined within blocks don't escape that context. This is an escape hatch, allowing it to build up results over time. The previous semantics around the for loop return value was that it'd behave like a map, returning all values. That semantic has been converted to `[for x in arr: x]` to encode generators.

This for-loop solution also inspired improvements to the object model. The lingering problems with objects as conceived before was managing consistency when you call methods within objects. The solution is to make objects closer to processes in the vein of smalltalk and erlang, rather than wrappers on state like Java. Objects hold onto state and can handle messages. You can't directly view an objects internal state, and objects do not have any methods which return values. They can send and receive messages, and hold onto state. 
    ```
    class Counter:
        count = 0
        increment(i): count + i
        value(response): response(count)
    ```
These semantics make them much more well-behaved in interacting with each other, forcing de-coupling and making them more lightweight coordinators of processes rather than stuffing all logic in there. This will lead to more decoupled styles, like Topics where updates are posted and broadcast. That'll lead to a more maintainable, decoupled architecture which can evolve with more independent pieces rather than the extend-and-append style that traditional OOP encourages. Message handling only commits the state, and fires of async processes at the end of the message - allowing it to be resilient in the precence of errors and keeping the object in a consistent state by deferring side-effects until the last possible minute.

The other aspect of concurrency in informal is Promises. Processes and Promises work together to give you safe, manageable concurrency that feels more natural. It doesn't impose a syntactic of conceptual tax on the codebase, instead giving you better performance and cleaner code.
You can turn any function call into a promise, by calling async on it. 
    ```
    compute_factorial.async(1000)
    ```
Which will give you an async version of that function that executes independently. You don't have to mark the function as async, and there's no function-coloring for what can call async. IO likewise reads like synchronous code by default, which yield control for other parts of the system to progress, and you have the option of marking it as async to get a reference to the value while continuing with the rest of the code. You can later wait on that result when you're ready to yield.

An improved error handling approach.
Exceptions
I explored various ideas around exceptions, algebraic effects and error values. Exceptions and algebraic effects are enticing, but thinking about them in more detail they lead to non-local control flow where the exception is handled several layers above where it happened. They lead to contextual behavior that varies depending on which code-path is taken to call a function - that kind of path-dependency makes code harder to debug, since you can't just reason about the code in isolation, but also how it arrived there. A truly-open form of effects is incredibly flexible, but imposes restrictions on how functions can be compiled/linked, and potentially adds a combinatorial factor to static analysis. 

Result types
Errors as values have nicer properties for analysis and coding. Rather than Result types, I agree with Rich Hickey's opinion that variants should be encoded as Union types (Int | Error) to make changes without breaking backwards compatibility. "Easing of requirements should be a compatible change" (i.e. Function required an Int before, but now it only requires a Maybe Int). "Providing a stronger return promise should be a compatible change" (Yesterday, the function returned Maybe y, but now it will always return Y). Go style error handling leads to code that is litterred with if err checks, making you wish for exceptions. Rust's try with ! doesn't solve it, it just gives you an easy footgun to panic if you want to ignore error handling. Elixir has a nicer solution, where there are two variants of core library functions, one which raises an exception and another which returns error values. That's functionally equivalent, but behaves better since elixir code runs in the context of supervisors so such errors are more isolated.

Informal errors
Informal's uses the errors as values approach, but with syntactic constructs to make them more ergonomic. 
First, you can handle error returns more succinctly in the context of whatever call is erroring. 
```
x = file.readline() if:
    IOException: ""
```
The match condition checks the return value, and if it matches, it gives you the fallback value, or if no branch matches, it uses the original return value. You have the full power of pattern matching conditionals when handling errors, and is much more readable - reading linearly as the base case, with exceptional cases defined as side-tracks in a collapsible block right underneath it. 
To handle a sequence of errors, you can chain this together with an early-return pattern. I'm still working through the syntax and details of this, but the key idea is that the function signature specifies return types and annotates it with a variable name. Assigning a value to that variable terminates the function. 
```
compute_baz() result Int | err Error:
    x Int | err = foo() 
    y Int | err = bar(x)
    result | err = baz(y)
```
If any of those result in an error, the error variant is returned. The expression on the left is pattern matched by type. This allows you to chain these errors together and easily propagate that up to some higher-level, which handles this process erroring overall. There are more details to be figure out on how exactly this can be expressed in-language using macros, but it's conceptually clean and easy to maintain. The code in both situations clearly indicate that an error can happen, without the use of additional keywords like "try". You're left with just your code, with minimal syntactic overhead.


Feb 18
Defined a cleaner syntax for map, fold and scan. 
There were several previous working idea. The best option would be to just define it as normal function operations on lists. That describes the operation with its name to those familiar with those functions (more common now, but will be unfamiliar to new programmers). The second option is to build it out of language constructs or have easier forms of it. 
You can define it as keywords, i.e. an "each" keyword which lets you map over attributes like foo(each arr). This behaves like a different kind of "spread" which maps over the variable. This has the advantage that you can use it along with normal arguments and it's in-place, giving a very readable style. It's like normalize-transpose semantics in array languages. For fold, you'd use an "over" keyword, but this fit in less well. You sometimes need to specify initial value for a fold, and there isn't a clean place to do that. It also doesn't follow the same logic as each. And these operators doesn't scale as well - if you have multiple "each", the semantics of that gets weird - do you do a zip, or do they behave like nested loops? 
The other option that works for operators is to use a broadcast keyword like "." to apply the function to everything. sum.(array). It's a bit invisible, but it's a succict way of expressing this concept. That'd look at the function signature and expand out arrays where the function expects the scalar variants. That works, but we again leave out fold - which is an incredibly useful construct. You can take the python approach and define foldable versions of core functions, like sum, min, max, etc. which covers about 80% of the use-case, but the other 20% do come up often enough to justify handling it better in the language. 
I've considered giving semantics to things like "calling an array = evaluating it", which also works. arr((x): x + 1) - it'd map. But then what to we do with fold? There can be variants, like [arr](fun) = map, and arr(fun) = fold. Another option was to treat it like 'distribute' - like 5(x + 2) = 5x + 10. So, (foo)(arr) = distribute it over the array elements. (fun)(arr) = fold. [fun](arr) = map. 
None of them felt quite right, until the variant today. Each is a construct we already support via the "for each" loop, which with the improvement yesterday can give you a lightweight map using for. [for x in arr: x + 1]. map does an operation for each element in an array, which is exactly what that reads like. So without knowing the language, you can look at it and figure out what it's doing.
fold is an operation interspaced over an array. Each required us to have a reference to the variable, since we needed to use it in the index. But over works without it. So you can do `sum = for arr: +` to get an expression like `arr[0] + arr[1] + ... arr[n]`. 
And this expands beautifully to scan as well, which is just a variant of this which keeps the intermediate results. Just like for loops vs maps, you do that by wrapping it in square brackets - `[for arr: +]` That's succict, clearly expresses that what you're getting back is an array, and you can understand the concept using primitives you already know!

String operations
I'm generally against adding extraneous keywords or operators, but the operators we do have should be flexible and work across different context in a meaningful way. 
Which raises the question - what do +, -, /, * mean in the context of a string? We can give it some meaningful semantics, which makes common string operations much nicer to compose.


`+` concat - appends onto the end of a string.
`/` divides, or splits a term. "hello world" / " " - splits the string by spaces, giving you ["hello", "world"]
`*` Distributes / multiplies a string across a series of string. A join. ["hello", "world"] * " " == "hello world"
`%` gives you the remainder, when you're splitting by multiple possible values. "a,b;d,f" % ("," | ";") == [",", ",", ";", ","]. It gives you just the delimiters, and allows you to reconstruct the string from the division and remainders.
str["hello"] - Gives you all byte-indexes of "hello" in the string. Indexing is lazy, so if you just want the first index, or the last, you just access the array - rather than having separate indexOf, lastIndexOf, with multiple argument variants.
str{ map } - transforms character sequences to others. Returns the string as a list with those replaced.

You can combine / and * to do find and replace, split and variations of it in flexible ways. You don't need separate versions of it which will work from the end of the string, or the beginning - they're composable functions you can use to create strings in flexible ways. 
`-` There are several potential meanings we can give minus. It could mean "replace", but you can easily achieve replace with / and *. It can be a mask operator, which would allow you to do padding like `"          " - "hello" = "hello     "`. But I think the most useful operation would be to define it as trim. You can use - as a unary prefix, `-str` to specify a trimmed version of a string with whitespace removed, or remove leading/trailing characters using `str - ' /'`, which removes sequences of any of those characters from both ends. I'm still split on whether to define it as padding for the operator case - `5 * "0" - "123" = "00000" - "123" = "00123".  // left-pad!`  It's useful, but mostly in the context of printing. And if formatted string literals are easy, it removes the need for it. So TBD.

Like other array operations, the compiler has the opportunity to fuse these together into higher-level operations which only scans the list once.


## Feb 21
How do we represent 'processes' as types? Types are able to model data very well, but lack the expressivity to model behaviors.
When we have a type declaration for a variable, it's a form of universal quantification - "x Int = foo() // x will always be an Integer".
But what is the equivalent for expressing existential quantification - there exists an x that meets these criterias.
The previous working sytnax for it was a "such that" operator "::"
x :: arr[x] = 0   // x such that array at the index x = 0
That variable now expresses the idea of all indexes where the value is 0. This lets you express a lot of inverse relationships in code in an elegant way.

Consider this beautiful prolog program for finding paths between nodes:
Path(x, y): Edge(x, y)          // There exists a path from x to y if there exists a direct edge from x to y
Path(x, y): Edge(x, z) Path(z, y) // Or if there exists some intermediate node z with an edge to x and a path to y. 

This succinctly captures the essence of this problem. Previously, we could express the notion of Types as predicates and iterate over all values where in that set. But we didn't have a way to express the idea of a free-variable like Z. The such-that statement gives you something close, but not quite. Extracting valid paths out of it also didn't have clear semantics.

The realization I had was this problem generalizes to one of representing any process. A process is a fundamental type of computation which generates values. Maps/functions transform values one to one, and types define a universe of values, while a process generalizes the notion of a processing step. Without realizing it, we have some forms of processes in our system already - the macro system is a primitive process - it gives you back a function which tells you how to process the next token. It does so without knowing how it's executed or what the next entity is - it's a composable component that can be mixed and matched by a higher-level process executing it. The for-loop syntax for reduce is also the simplest form of a process, and the message-based actor/object protocol is also a form of process.

This unifies all of that and makes them better. What really made the pieces click into place was Rich Hickey's talk on Trandsucers. The core principle behind a transducer is that it's a composable piece of transformation by generalizing "reduce". That has the expressive capability to express all kinds of operations on collections, like map, filter, etc. while being entirely independent of what the collections are or how these operations fit together. Beautiful stuff. 

We build on those ideas to create pattern based typed, composable processes. Consider the problem of topological sort - look through the Rosetta Code implementations in other language - https://rosettacode.org/wiki/Topological_sort - it gets fairly complex, with a lot of bookkeeping and logic. The fundamental idea behind a solution is lost in such an implementation. With process patterns, you'd define a topological sort algorithm as something like this:

```
for:
    Leaves: find_leaves(RemainingEdges)
    Path: Path + Leaves
    RemainingEdges: Edges - Path
```
This is pseudocode, but the core idea here is that this defines the essence of the process in terms of a single step. When you pattern-match in an if/match condition, it matches one of the patterns. The patterns here are declarative data-flow definitions of each of the variables in terms of each other and the previous step.
The logic for how this is initialized and how termination is managed are still being sorted out. But this captures the essence of this process. You can now take that definition and analyze the process, the dependencies between each step in the process and statically analyze its execution semantics. The process is independent of how it's executed - you can you this same definition to find one path, find all paths, run it sequentially or in parallel. You can save the 'process' as a value, and then compose it in higher-level processes - for example, if you wanted to add a process to select the shortest paths. They become self-contained units of processes that you can then mix-and-match to build higher-level processes. Their semantics become more well-typed, closer to a state-machine.

This gives you the semantics for describing free-variables in Types. You can statically analyze it, and prove things about it. The implementation is much cleaner, and captures the essence of the problem, giving you the flexibility to re-use it whereever this problem comes up in a truly portable way. Just like transducers, the steps themselves are composable, so when you have a series of these processes they efficiently collapse together into a higher-level process without the inefficiency of duplicate iterations (loop fusion). 

I'm already thinking of ways to apply this to the compiler. The compiler is a process for converting text into executable code after all, with many sub-processes for lexing, parting, type-checking, etc. You can write each part of the compiler as small processes, in the nano-pass style, while combining it together at the end so that it executes as if it's doing a single fused pass over the code. This formulation also makes it well-suited for parallel and incremental compilation when used in combination with immutable data structures. 
It's one of those core concepts that fundamentally change how you program in Informal. There's a lot to be figured out, but I'm excited by the possibilities this opens up.



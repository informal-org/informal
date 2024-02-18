# February 2024

Feb 03
In the past week, built out a table-driven parser in Zig. It uses a fairly compact low-level representation of a state-machine using a bitset to specify which characters match, and popcount to find state transitions. The state machine supports operations such as push and pop onto a secondary stack, allowing it to parse things like precedence efficiently. 
The idea was to write a table generator from a language grammar into this format, emit the table as a CSV file, write hardcode in a table for parsing CSV files. Thus, the grammar would be full encoded in a file which can be read by both the bootstrapping language and by early versions of Informal which would only need to implement the parsing engine to run the table. That allows you to bootstrap the language more easily by splitting up grammar -> table and table -> ast steps.
Decided to pivot away from this approach after figuring out a way to make macros elegantly handle operators and all syntactic blocks. This leads to a much simpler core language with greater flexibily. Since it doesn't need any of the low-level capabilities of Zig, I'm reviving an earlier draft of the language in JS/TS to bootstrap the language faster.

Feb 10
Got the revived language in a working state with tests passing. The test-suite of expressions built out previously was invaluable in getting this back up and running. 

Feb 17
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

--------
Trying to find a unique file extension that hasn't already been used in other contexts is tough. There's no universal repository of extensions. Some options were .inf, .if, ix, .infr, .ifn, .form, .inform. All of those were taken to various degrees. I used .infr for a while, but its abbreviated style doesn't suite the style. If "informal" was slightly shorter, I'd use the full name. 
The final alternative is .ifi, pronounced like "iffy". It's fun to say and type, and its character aligns with the informal character of the language. It's named in the same spirit as "git". It also looks unused from github searches, which would allow us to define syntax highlighting for it at some point if there's ever enough code using it (unlikely).

<img src="https://raw.githubusercontent.com/Feni/informal/main/Docs/Resources/Images/oto.jpg" width="205" alt="Oto, the octopus">


# Informal Programming Language
Informal is a flexible, general purpose programming language.

This language is in active, early stage development. You can play with it for hobby projects and provide feedback, but it's not ready for serious production use yet. Watch this repo on GitHub and check back soon!
 
## A pattern based language
Everything in Informal is built on a single concept: Pattern Matching. Patterns generalize the functional mapping from input -> output, define the structural mapping for types and the relations between the two. That means that you can manipulate any functionality, just as flexibly as data or declaratively query for results meeting the specified constraints.


## Syntax

Comments and Documentation
```
// Single line comments

/// Documentation blocks
    Can span multiple, indended lines.
    
    Indent further to embed blocks of code.
    Use >>> to test for expected results.
 
        1 + 2
    >>> 3
    
```

Variables and Types
```
hello world : String = "Hello, World!"

// Types can be inferred.
is spring = True

// Types can depend on other types (Generic Types) or on values (Dependent Types).
power level : Int(32) = 9000

fn slice(arr : Array, index : Int index < arr.size) Array(size=index): ...


```

Printing to console
```
// Print with a new line
print("Hello, World!")

// Or specify a different line-ending.
print("a", "b", "c", separator=" ", ending="")
```

Conditions
```
// Informal has just a single conditional operator - the pattern-matching "if".
sunny: go outside()
rainy: 
    go outside with umbrella()
    jump in puddles()
_: stay inside()


// You can use it as a switch case. 
// Conditions are expressions, so you can capture their result and store it as a variable.
ch = '7'
classify letter = ch:
    ' ': "ch is a Space"
    'a'..'z' | 'A'..'Z': "ch is a Letter"
    '0'..'9': "ch is a Digit"
    else: "ch is something else"


// Or match by structure
result = (n % 5, n % 3):
    (0, 0): "FizzBuzz"
    (0, _): "Fizz"
    (_, 0): "Buzz"
    (_, _): n

// Or specify each branch separately
user.email:
    send confirmation email(user.email)
user.phone or user.messenger id:
    send confirmation text(user)
```

Array operators and functional constructs replace the need for most loops, but Informal still comes with a flexible loop to process any kind of data.
```
// The built-in for loop can be used as a for-each.
[1..5].each:
    (x): x + 10

// You can specify a second parameter to get the index
arr = [1, 2, 3, 4, 5]
(0.., arr).enumerate:
    (index, value): value + index

// You can similarly loop over maps.
// Loops are also expressions, which return values

months: {"January": 1, "February": 2, "March": 3, "April": 4, 
        "May": 5, "June": 6, "July": 7, "August": 8, 
        "September": 9, "October": 10, "November": 11, "December": 12}

invert_months = months.each:
    (month str, month num): { month_num : month_str }

// You can iterate over multiple data streams at once. 
// This often comes in useful for "zipping" values together.
brr = [10, 20, 30, 40, 50]
(arr, brr).each:
    (x, y): x + y

// [11, 22, 33, 44, 55]

// You can specify guard clauses to break out of loops early.
[1..10].until{ (x): x > 4 }.each:
    x + 10

```

```
// Array operations
2 * [10, 20, 30]
// [20, 40, 60]

[10, 20, 30] + [5, 5, 5]
// [15, 25, 35]

// Declarative ranges specify what the result should look like.
[1..10]
// [1, 2, 3, 4, 5, 6, 7, 8, 9]

// You can specify the first few elements, and range will fill it in.
[0, 10, 20, .., 100]
// [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]

hex_characters = "0"..,"9" + "A"..,"F";
// "0123456789ABCDEF"

// Composable filters
array = [5, 10, 15, 20, 25]

// You can index into the array by numeric indexes
[lo, mid, high] = array[-1, array.length / 2, 0]
// Or specify with a boolean list whether an element should be returned or not.
arr[arr % 2 == 0]
// [10, 20]

```

Functions, Types and the patterns beneath it all
```
// Everything in Informal is built on a single concept. Pattern Matching.
// Functions are a mapping that transform an input to an output.


// Anonymous functions
(x) : x + 1

// Named functions

concat([], []): []
concat([], [a]): a
concat([a, ...restA], Array b): [a, ...concat(restA, b)]

// We can then use this function backwards, to query the language for all pair of lists which concat to give a given result.

// A lambda that maps a variable A, B such that concating the two will match [1, 2, 3]
A, B : concat(A, B) = [1, 2, 3]
// Uppercase predicate parameters are available in-scope with values matching the predicates.
print(A, B)

// A = [], B = [1, 2, 3]
// Or query for all possibilities
A[], B[] : concat(A, B) = [1, 2, 3]
// A = [], B = [1, 2, 3]
// A = [1], B = [2, 3]
// A = [1, 2], B = [3]
// A = [1, 2, 3], B = []

// You can define structure and match with it.

DateString:
    year : string.Digits(4)
    "-"
    month : string.Digits(2)
    "-"
    day : string.Digits(2)


// Use destructuring to unwrap the data by patterns, without regex.
d: DateString = "2023-03-05"
d.year == "2023"
// Or forward, to use it as a pattern to encode the data.
d2 = DateString(year="2023", month="03", day="05")
d == d2


// Macros and meta programming
// Macros can be defined as just regular functions, which take in code and return new code.

fn cache(code: Expression) Expression:
    code.arguments[1]


```

# Pipeline
x = readInt() |>
    0: 0
    (x) :: 1/x


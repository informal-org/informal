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
// Variable names can contain spaces. Yes, really.
String hello world = "Hello, World!"

// Types can be inferred.
is spring = True

// Types can depend on other types (Generic Types) or on values (Dependent Types).
Int(32) power level = 9000

fun slice(Array arr, Int index < arr.length) Array(size=index):
// Or more explicitly as slice(Array arr, Int index if index < arr.length)    

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
if sunny:
    go outside()
else if rainy:
    go outside with umbrella()
else:


// You can use it as a switch case. 
// Conditions are expressions, so you can capture their result and store it as a variable.
char type = if ch:
    ' ': "ch is a Space"
    'a'..'z' | 'A'..'Z': "ch is a Letter"
    '0'..'9': "ch is a Digit"
    else: "ch is something else"

// You can match against other kinds of operators
if grade >:
    90: "A"
    80: "B"
    70: "C"
    60: "D"
    else: "F"

// Or match by structure
if (n % 5, n % 3):
    (0, 0): "FizzBuzz"
    (0, _): "Fizz"
    (_, 0): "Buzz"
    (_, _): n

// Or specify each branch separately
if:
    user.email:
        send confirmation email(user.email)
    user.phone OR user.messenger id:
        send confirmation text(user)
```

Array operators and functional constructs replace the need for most loops, but Informal still comes with a flexible for loop to process any kind of data.
```
// The built-in for loop can be used as a for-each.
for x in [1..5]:
    x + 10

// You can specify a second parameter to get the index
arr = [1, 2, 3, 4, 5]
for index, value in arr:
    value + 10

// You can similarly loop over maps.
// Loops are also expressions, which return values

months: {"January": 1, "February": 2, "March": 3, "April": 4, 
        "May": 5, "June": 6, "July": 7, "August": 8, 
        "September": 9, "October": 10, "November": 11, "December": 12}

invert months = for month str, month num IN months:
    { month num : month str }

// You can iterate over multiple data streams at once. 
// This often comes in useful for "zipping" values together.
brr = [10, 20, 30, 40, 50]
for x IN arr, y IN brr:
    x + y

// [11, 22, 33, 44, 55]

// You can specify guard clauses to break out of loops early.
for x IN [1..10]: if x < 4
    x + 10

// Or leave out the conditional clause, to loop "while" the guard-clause is true.

n = 12
for: if n != 1
    if n % 2:
        n = n / 2
    else:
        n = 3*n + 1

```


```kotlin
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

fun concat([], []): []
fun concat([], [a]): a
fun concat([a, ...restA], Array b): [a, ...concat(restA, b)]

// We can then use this function backwards, to query the language for all pair of lists which concat to give a given result.

// Find a variable A, B such that concating the two will match [1, 2, 3]
A, B :: concat(A, B) = [1, 2, 3]

// A = [], B = [1, 2, 3]
// Or query for all possibilities
A[], B[] :: concat(A, B) = [1, 2, 3]
// A = [], B = [1, 2, 3]
// A = [1], B = [2, 3]
// A = [1, 2], B = [3]
// A = [1, 2, 3], B = []

// You can define structure and match with it.

DateString:
    year string.Digits(4)
    "-"
    month string.Digits(2)
    "-"
    day string.Digits(2)


// Use destructuring to unwrap the data by patterns, without regex.
DateString d = "2023-03-05"
d.year == "2023"
// Or forward, to use it as a pattern to encode the data.
d2 = DateString(year="2023", month="03", day="05")
d == d2


// Anonymous functions
(x): x + 1
// You can avoid naming x in these cases.
array.map(_ + 1)


// Macros and meta programming
// Macros can be defined as just regular functions, which take in code and return new code.

fun cache(Expression code): Expression
    code.arguments[1]


```


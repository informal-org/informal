<img src="https://raw.githubusercontent.com/Feni/informal-landing/master/static/images/informal_logo.png" width="205" alt="Informal lang logo">


# The Informal Programming Language.

Informal is a flexible, general purpose programming language targeting WebAssembly.

This language is in active, early stage development. We welcome you to play with it for any hobby projects and provide feedback, but it's not ready for serious production use yet. Star and watch this repo on GitHub and check back soon!

## A pattern based language
Everything in Informal is built on a single concept: Pattern Matching. Patterns generalize the functional mapping from input -> output, define the structural mapping for types and the relations between the two. That means that you can manipulate any functionality, just as flexibly as data or declaratively query for results meeting the specified constraints.


## Examples

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

match (n % 5, n % 3):
    (0, 0): "FizzBuzz"
    (0, _): "Fizz"
    (_, 0): "Buzz"
    (_, _): n


// Everything in Informal is built on a single concept. Pattern Matching.
// Functions are a mapping that transform an input to an output.

fun concat([], []): []
fun concat([], [a]): a
fun concat([a, ...restA], b: Array): [a, ...concat(restA, b)]

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

DateYMD {
    year string.Digits(4)
    "-"
    month string.Digits(2)
    "-"
    day string.Digits(2)
}

// Use destructuring to unwrap the data by patterns, without regex.
d: DateYMD = "2023-03-05"

// Functional primitives.
// Use "each" to map over each element of an array. 
double_array = double(each array)


// Anonymous functions
x: x + 1
// You can avoid naming x in these cases.
array.map(_ + 1)


// Macros and meta programming
// Macros can be defined as just regular functions.

fun cache(code: LazyExpression) LazyExpression {
    code.arguments[1]
}

```


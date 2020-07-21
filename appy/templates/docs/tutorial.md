# Introduction
A simple language with a handful of flexible constructs to give you the full expressive power of programming language in a small package.
A small core with flexible operations.

## Basic operations
```ruby
1 + 1        # 1
10 * 2.5     # 25.0
```

```ruby
"Hello, " + "world!"
# "Hello World"
```

// todo: Variables. Order independent, immutable, scoped.

## Lists
You can combine elements into lists. 
```ruby
[1, 2, 3]
```

AppAssembly lets you to perform operations on entire lists, avoiding a lot of loops.

```ruby
2 * [10, 20, 30]
# [20, 40, 60]
[10, 20, 30] + [5, 5, 5]
# [15, 25, 35]
```

Use `;` to combine lists, or to add elements before or after a list.
```ruby
arr = [1, 2, 3]
brr = [10, 20, 30]
combined = [arr; brr]
# [1, 2, 3, 10, 20, 30]
```

Lists can contain data of various types
```ruby
[9, 27.0, true, false, "hello", :symbol]
```

You can create multi-dimensional arrays using `;` 
```ruby
[1, 0, 0
 0, 1, 0
 0, 0, 1]
# [1, 0, 0;
#  0, 1, 0;
#  0, 0, 1]
# Use a ; to define it inline
center_row = [0, 1, 0]
matrix = [1, 0, 0; center_row; 0, 0, 1]
```

### Generating lists
You can specify a range of numbers using `..`
```ruby
[1..10]
# [1, 2, 3, 4, 5, 6, 7, 8, 9]
```
You can list out the first few elements and the range expression will try to fill in the values in between.
```ruby
[0, 10, 20, .. 100]
# [10, 20, 30, 40, 50, 60, 70, 80, 90]
```
You can create an inclusive range by specifying elements that would appear after the range with a comma `..,`
```ruby
[100, 90, .., 10, 0]
# [100, 90, 80, 70, 60, 50, 40, 30, 10, 0]
```

You can use ranges on characters as well. 
```ruby
hex_characters = [["0"..,"9"]; ["a"..,"f"]]
# ["a", "b", "c", "d", "e", "f"]
```
You can also leave out the last element to generate an infinite sequence. Ranges are generated lazily on-demand, so these operations are fast and don't take up any extra space in memory.

Later on, you'll see how you can generate arbitrary lists with custom functions as well.

### Indexing
You can get the element at a particular position in the list using the index operator `[]`
```ruby
arr = [10, 20, 30, ..100]
arr[0]
# 10
```
List indices start at zero. Use a negative index to lookup an item from the end.
```ruby
arr = [5, 10, 15, 20, 25]
arr[-1]
# 25
```
You can also pass in a list of indexes and it'll give you the elements at those indexes in that order.
```ruby
arr = [5, 10, 15, 20, 25]
arr[-1, 2, 0]
#[25, 15, 0]
```
Combining this indexing with the range operation, you can access array slices using the same syntax
```ruby
arr = [10, 20, 30, 40, 50]
arr[1..]        # Get elements at index 1, 2, 3 ... (all elements except first)
# 20, 30, 40, 50
arr[..-1]       # Get all elements except last
# 10, 20, 30, 40
```

You can also index with a boolean list to specify whether an element should be returned or not. 
```ruby
arr = [5, 10, 15, 20, 25]
arr[false, false, true, true, true]
#[15, 20, 25]
```
Combining this with boolean array operations give you a powerful filtering operation.
```ruby
arr = [5, 10, 15, 20, 25]
arr > 10
# [false, false, true, true, true]
arr[arr > 10]   # Read as arr where arr is greater than 10
# [15, 20, 25]
arr[arr % 10 == 0]
# [10, 20]
```
Later on, you'll see how functions let you perform even more flexible filtering.

## Maps
```ruby
greetings:
    "English": "Hello!"
    "Hindi": "नमस्ते"
    "Malayalam": "നമസ്കാരം"
    "Spanish": "Hola!"
    "Computer": "beep boop bop beep"
```

You can access a map by a key or a list of keys.
```ruby
greetings["English"]
# "Hello!"
```

Let's give a customary greeting back to our computer
```ruby
words = greetings["Computer"].split()
# ["beep", "boop", "bop", "beep!"]
words.join("! ")
# beep! boop! bop! beep!
```

You can use maps as objects
```ruby
movie:
    title: "Inception"
    year: 2010
    director: ["Christopher Nolan"]
    starring: ["Leonardo DiCaprio", "Ellen Page", "Ken Watanabe", "Joseph Gordon-Levitt", "Marion Cotillard", "Tom Hardy",  "Cillian Murphy", "Michael Caine"]
    music: ["Hans Zimmer"]
    genre: [:sci_fi, :action, :adventure]

movie.title     # "Inception"
```

This object is made up of mappings from symbolic names to their values. Symbols are not strings. Symbols represent an abstract idea, like the concept of `true`, `null` or `:title`. All of the keywords, function names and attributes you see in code are symbols. Once compiled, their attributes names don't matter, just the concept they represent. 
```ruby
movie.title       # "Inception"
movie["title"]    # null
movie[:title]     # "Inception"
```

The `:` operator allows you to define maps, enclosed by their whitespace block. You can also define a map inline using curly braces (`{ }`) and commas(`,`)
```ruby
movie: {title: "Wall-E", year: 2008, genre: [:animation, :adventure, :family]}
```

## Tables
...

## Conditionals
```ruby
happy = true
know_it = true

if happy and know_it:
    "Clap"
else:
    ":("
```
The values `false`, `null`, `0`, `[]` and `{}` are considered logically false. Everything else is considered true when evaluating a condition. 
Since everything in AppAssembly is built on immutable values, the `==` operator checks whether two **values** are equal, rather than checking if they share the same memory location. So two lists are equal when they contain the same values. Equality on maps and sets check for the same keys and values, irrespective of order.
```ruby
[0, 1, 2, 3, 4] == [0..5]
# true
```

Conditionals are expressions too, so you can assign the result of a conditional to a variable
```ruby
n = 10
odd_or_even = if n % 2 == 0:
    "Even"
else:
    "Odd"
# Or written inline
odd_or_even = if n % 2 == 0 then "Even" else "Odd"
```

You can add multiple conditions using `else if` branches.
```ruby
if n % 3 and n % 5 == 0:
    "FizzBuzz"
else if n % 3 == 0:
    "Fizz"
else if n % 5 == 0:
    "Buzz"
else:
    n
```

## Pattern Matching
Maps support all kinds of keys beyond just basic types.
Here we have a mapping from numerical grade to a letter grade using ranges.
```ruby
grades:
    90..: "A"
    80..90: "B"
    70..80: "C"
    60..70: "D"
    ..60: "F"

grades(83)
```



## Functions
A function is a mapping from some input to some output, allowing you to define abstract relationships between things. Functions can be defined just like maps. The parentheses are required and denote the input parameters.
```ruby
add(a, b): a + b
add(5, 4)
# 9
```
With this, we can define a function to calculate fibonnaci numbers. 
```ruby
fibo:
    0: 1
    1: 1
    (n): fibo(n-1) + fibo(n-2)
```
The recursive definition of fibonnaci is elegant, but not the most efficient since it'll have to re-calculate the fibonnaci numbers repeatedly. Let's define it as a generator instead.
```ruby
fibo = [1, 1, (index, arr): arr[-1] + arr[-2], ..]
# 1, 1, 2, 3, 5, 8, 13 ...
```
There! We have an infinite sequence of all of the fibonnaci numbers. We can index into this list, and it'll generate just enough of the list to return our result.
The range function uses the function we provide to calculate the n-th element based on based on previous elements. 

There's actually a formula to calculate the nth fibonnaci number in constant time, without needing to know the previous elements.
```ruby
binet_formula(n):
    phi = (sqrt(5) + 1) / 2
    reciprocal = -1 / phi
    round((phi^n - reciprocal^n) / sqrt(5))
```
Just like everything else in AppAssembly, functions are expressions, which means they always return a value. When a function contains multiple lines, it'll return the result of the last expression. 

Now that we have a formula to calculate a fibonnaci number, we can easily generate a list of all of them.
```ruby
fibo_seq = [binet_formula, ..]
# [1, 1, 2, 3, 5, 8, 13, ..]
fibo_seq[1, 10, 20, 30]
# [1, 55, 6765, 832040]
```
Since this doesn't rely on the previous array elements parameter, the generator can return arbitrary elements lazily without calculating or storing the other elements. 

TODO: Function guards, combining functions with maps, multi-methods.

## Loops
Array operations, pattern matching, filtering and generators removes the need for most loops. When you do find yourself needing to write something out long-form, AppAssembly has a flexible `for` loop.
```ruby
arr = [1, 2, 3, 4, 5]

for x in arr:
    x + 10
# [11, 12, 13, 14, 15]
```
You can add a second parameter to get the index as well
```ruby
for index, value in arr:
    value + 10
```
Similarly, you can loop over just the keys or the keys and values in maps

// TODO: Better example
```ruby
for key in greetings:
    key + "!"
# ["English!", "Malayalam!", "Hindi!", "Spanish!" "Computer!"]

for key in greetings:
    value : key
# Array of map elements with key & value flipped.
```

You can loop over multiple arrays simultaneously. This often comes in useful for "zipping" values together from multiple lists.
```ruby
brr = [10, 20, 30, 40, 50]
for x in arr, y in brr:
    x + y
# [11, 22, 33, 44, 55]
```
The loop will terminate when you reach the end of the smaller array.
You can specify an explicit condition for whether the loop should "continue", having the iteration automatically "break" when it's false.
```ruby
for x in [1..10] if x < 4:
    x + 10
# [11, 12, 13]
```
If you leave out the iteration clause, you get a while loop that continues as long as a condition is true. Since variables in AppAssembly are immutable and scoped to their block, setting a value inside a loop won't have a side effect outside of the loop.
```ruby
# Hailstone sequence
n = 12
for if n != 1:
    if n % 2:
        n = n / 2
    else:
        n = 3*n + 1
# [12, 6, 3, 10, 5, 16, 8, 4, 2, 1]
# Outside of the loop, n remains the same.
n == 12
# true
```


## Combinations

## Types and classes

## Extension functions

## Embedded languages

## Actions and concurrency

## Conclusion
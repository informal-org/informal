# A New Language For The Web
AppAssembly is a general purpose programming language for building full-stack web applications. We take a handful of simple concepts and combine them in flexible ways to give you the full expressive power of a modern programming language, in a friendly visual environment. This guide walks you through all of the concepts you need to get started programming in AppAssembly.

You'll learn how to:
* Use array programming and pattern matching to reduce boilerplate code.
* Write declarative code that favors plain data over abstractions.
* Use functions to boost expressiveness throughout the language.
* Incrementally add gradual typing to add structure to your program.
* Replace regex with declarative patterns for common parsing tasks.
* Get 4-16x the performance with seamless concurrency.
* Simplify refactoring without breaking compatibility or requiring cascading changes.
* Manage errors in a resilient way.
* Extend and adapt the language to suit your needs.


## An Observable Visual Environment
Most bugs in software stem from a disconnect between our mental models of the problem and the complexities of reality. So often, we're coding blind with vague requirements and a limited input-output view into what our software is actually doing. 
AppAssembly removes this blindfold. You're connected directly to your running system, so you can explore the problem domain and incrementally compose code that you can see and interact with. 

To get started, try playing around with the expression in the cells below:
```ruby
"Hello, " + "world!"
# "Hello World"
```

All code in AppAssembly lives in these spreadsheet-like cells. You can write entire programs in these cells, but we recommend building your program out of many smaller cells you can observe. 
```ruby
1 + 1        # 1
10 * 2.5     # 25.0
```

Cells have a name and an expression. You can reference a cell by its name and when the cell value changes, all of its references are automatically updated. Just like in Excel. 
```ruby
n = 5
squared = n * n
# 25
```
Cells are lexically scoped to the block they're defined in. They're order-independent, so you can think of them as stating facts that always hold true rather than issuing instructions. 

Cells contain values, but they're not mutable variables. Values are immutable. Just like you don't mutate the meaning of a number when you do `2 + 3` or mutate a string when you do `"hello".uppercase()`, all operations return a new transformed value. Values are easier to observe and reason about than state which may be mutated by each line of code. Under the hood, this is equivalent to the SSA (Static Single Assignment) form that many compilers use to optimize code.
Even though values are immutable, you can re-bind a name to a new value using `=` for a familiar imperative style. 
```ruby
n = 5
n = n * 2
# n = 10
```
Later on, you'll see how you can use actions to manage state in a concurrency safe way.

## Array Programming
Lists in AppAssembly let you group elements together into a larger unit you can operate on. 
```ruby
[1, 2, 3]
# [1, 2, 3]
```
Lists can contain data of various types.
```ruby
[9, 27.0, true, false, "hello", :symbol]
```
You can perform operations over the entire collection. No loops required!
```ruby
2 * [10, 20, 30]
# [20, 40, 60]
[10, 20, 30] + [5, 5, 5]
# [15, 25, 35]
```
Multi-dimensional arrays are created by defining each row on its own line.
```ruby
1, 0, 0
0, 1, 0
0, 0, 1
# [[1, 0, 0]
#  [0, 1, 0]
#  [0, 0, 1]]
center_row = [0, 1, 0]  # Use ;; to define it inline
matrix = [1, 0, 0 ;; center_row ;; 0, 0, 1]
# [[1, 0, 0]
#  [0, 1, 0]
#  [0, 0, 1]]
```

Use `;` (read as "followed by") to combine lists, or to append or prepend elements onto a list. You can also use the spread syntax, `...`, to expand a list in-place.
```ruby
arr = [1, 2, 3]
brr = [10, 20, 30]
sub_arrays = [arr, brr]
# [[1, 2, 3], [10, 20, 30]]
spread_array = [arr, ...brr]
# [[1, 2, 3], 10, 20, 30]
combined = [arr; brr]
# [1, 2, 3, 10, 20, 30]
[99; arr]
# [99, 1, 2, 3]
[arr; 99, 100]
# [1, 2, 3, 99, 100]
```

### Declarative Ranges
Whenever possible, AppAssembly tries to define operations in a declarative style where you specify what the result should look like, rather than use separate functions like `concat`, `append`, `prepend`, `range`, etc.

For example, to create a range of numbers, just specify the beginning and end.
```ruby
[1..10]
# [1, 2, 3, 4, 5, 6, 7, 8, 9]
```
You can list out the first few elements and the range expression will determine the step and fill in the values in between.
```ruby
[0, 10, 20, .. 100]
# [10, 20, 30, 40, 50, 60, 70, 80, 90]
```
We can make this an inclusive range by specifying elements that would appear after the range with a comma `..,`
```ruby
[100, 90, .., 10, 0]
# [100, 90, 80, 70, 60, 50, 40, 30, 10, 0]
```
Ranges can figure out any sequences that can be expressed as `a*x + b`, so you can count up, down or sideways. 
They work on other data types as well, including characters. 
```ruby
hex_characters = ["0"..,"9"; "a"..,"f"]
# ["0", "1, "2", "3", "4", "5", ...]
```
If we leave out the last element, we get a an infinite sequence. 
Ranges are generated lazily on-demand, so these operations are fast and don't take up any extra space in memory.

Soon, with functions, you'll be able to generate any arbitrary sequence you can imagine!

### Composable Filtering
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
Indexing is just a special case of filtering. So you can also pass in a list of indexes and it'll filter the list to the elements at those indexes, in the given order.
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
And that's just for starters. With functions, you'll be able to slice and dice through any dataset with ease. 

## Pattern Matching Maps
Mapping defines the relationship or association between elements.
```ruby
greetings:
    "English": "Hello!"
    "Hindi": "नमस्ते"
    "Malayalam": "നമസ്കാരം"
    "Spanish": "Hola!"
    "Computer": "beep boop bop beep"
```

Just like list indexing, you can access a map by a key or a list of keys.
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

The `:` (association) operator allows you to define maps, enclosed by their whitespace block. You can also define a map inline using curly braces `{ }`.
```ruby
movie: {title: "Wall-E", year: 2008, genre: [:animation, :adventure, :family]}
```
### Pattern Matching
Maps support all kinds of keys beyond just basic types.
Here we have a mapping from numerical grade to a letter grade using ranges.
```ruby
grades:
    90..100: "A"
    80..90: "B"
    70..80: "C"
    60..70: "D"
    0..60: "F"

grades(83)
# B
```

// TODO: Pattern matching destructuring


### Conditionals
```ruby
happy = true
know_it = true

if happy and know_it:
    "Clap"
else:
    ":("
```
The values `false`, `null`, `0`, `[]` and `{}` are considered logically false. Everything else is considered true. 
Since AppAssembly is built on immutable values, the `==` operator checks whether two **values** are equal, rather than checking if they share the same memory location. So two lists are equal when they contain the same values. Equality on maps and sets check for the same keys and values, irrespective of order.
```ruby
[0, 1, 2, 3, 4] == [0..5]
# true
```

Conditionals are expressions too, so you can assign the result of a conditional to a variable
```ruby
n = 10
# Inline using 'then' in place of :
odd_or_even = if n % 2 == 0 then "Even" else "Odd"
# Or written in multiple lines
odd_or_even = if n % 2 == 0:
    "Even"
else:
    "Odd"
```

You can add multiple conditional branches using `else if`.
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


### Set, Table and Matrix
...



## Functions are a Superpower
A function is an abstract mapping from some input to some output, allowing you to define general relationships between data. So functions are just abstract maps.
```ruby
add(a, b): a + b
add(5, 4)
# 9
```
The best type of code is just data. Data is plain, simple and easy to understand. It's practically equivalent to the unit tests you may write for it. Functions can be defined as just lookup tables of plain data, or as calculations. Whatever suits the problem.
```ruby
fibo:
    0: 1
    1: 1
    (n): fibo(n-1) + fibo(n-2)
```
This recursive definition of fibonnaci is elegant, but not the most efficient since it'll have to re-calculate the fibonnaci numbers repeatedly. Let's use a function to show the range expression how to generate the n'th fibonnaci number from previous elements.
```ruby
fibo = [1, 1, (index, arr): arr[-1] + arr[-2], ..]
# 1, 1, 2, 3, 5, 8, 13 ...
```
There! We have an infinite sequence of all of the fibonnaci numbers. We can index into this list, and it'll generate just enough of the list to return our result.

There's actually a formula to calculate the n'th fibonnaci number in constant time, without needing to know the previous elements.
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
fibo_seq[10, 20, 30]     # Select the fibonnacci numbers at indices
# [55, 6765, 832040]
```
Since this doesn't rely on the previous array elements, the generator can return arbitrary elements lazily without calculating or storing the other elements. 

Alright, enough fibonnaci numbers. There's a lot more you can do with functions. 

TODO: Function guards, combining functions with maps, multi-methods.

## The One Loop `for` Everything
(that you probably won't even need...)

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


```ruby
months: {"January": 1, "February": 2, "March": 3, "April": 4, 
        "May": 5, "June": 6, "July": 7, "August": 8, 
        "September": 9, "October": 10, "November": 11, "December": 12}

# Invert the keys and values in the months map
for month_str, month_num in months:
    { month_num : month_str }
```

You can loop over multiple arrays simultaneously. This often comes in useful for "zipping" values together from multiple lists.
```ruby
brr = [10, 20, 30, 40, 50]
for x in arr, y in brr:
    x + y
# [11, 22, 33, 44, 55]
```
The loop will terminate when you reach the end of the smaller list.
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
## Types are the Essence of Data
Types are a set, class or category of data. They define the essential properties of the members of that type, allowing you to operate on them with clearly stated assumptions. A good type definition will make your code faster, safer and cleaner. Types are completely optional in AppAssembly. If you find yourself doing a lot of `if` validation checks within your function, that may be a good place to use types.

For example, here's a Movie type stating that all movies have a `name` and `release_date`.
```ruby
Movie:
    String name
    Date released_on
```
We can require a parameter to be of a particular type in the function signature, and then use it with confidence in the function body.
```ruby
get_snippet(Movie movie):
    movie.title + " (" + movie.released_on.year + ")"
```
Any Map that meets the type specification can be explicitly cast into a Movie.
```ruby
wall_e = {name: "Wall-E", released_on: Date(2008, 07, 27)}
Movie wall_e = wall_e as Movie      # Cast wall_e to the type Movie
```
Constructors make it easier to create instances of a type. They always have the same name as the type.
```ruby
Movie:
    Movie(String name, Date released_on)

life_of_pi = Movie("Life of Pi", Date(2012, 11, 21))
```
This gives you a default constructor that automatically initializes the fields.
You can add methods to a class. 
```ruby
Counter:
    Counter(Integer count)
    inc(): this.count + 1
    dec(): count - 1        # The "this" keyword is implicit when referencing instance variables defined in the class

c1 = Counter(9)
c2 = c1.inc()
# c2 = Counter(10)
```
Methods allow you to group data together with the behaviors that operate on them. Here, the increment and decrement methods give you back a *new* instance of Counter. When you do `this.count + 1`, the result of that operation is a new instance of `this` with count incremented. At the end of this, c1 still has a count of 9, while we have a new counter, c2, with a count of 10. What if you wanted to modify c1 in-place? You'll see how to do that with Concurrent Actions, soon!
The `this` keyword is implicitly present in all objects and allow you to unambiguously refer to the object's attributes.
To define static class methods that are shared by all instances, define them under the Class's name.
```ruby
Counter:
    Counter(Integer count)
    inc(): this.count + 1
    dec(): count - 1
    Counter.max_count: 100

# Call class methods by the class name
Counter.max_count
```
In the next section, you'll see how this is used to implement interfaces and extension functions.

Since these classes are defined just like functions and maps, we can pass parameters to use them as Generic Classes.
```ruby
Counter(T):
    Counter(T count)
    inc(T amount): count + amount

IntCounter = Counter(Integer)
FloatCounter = Counter(Float)
```
This uses multiple dispatch to call the outer Counter generic class to create an instance of the Counter class parameterized to the type T. 


## Designed to Adapt
It's not the fastest software that survives, nor the most elegant, but the one most adaptable to change. Change is that one constant in software we must contend with. Unfortunately software changes often mean breaking compatibility, introducing bugs or requiring a lot of cascading changes. As projects grow in size, they often become rigid and harder to change.

AppAssembly supports incremental software development in a number of ways. The **Type System** ensures that the underlying assumptions of the system remain true through changes. **Multi-methods** allow flexible compatibility for APIs. **Extension Functions** keeps libraries small and allow you adapt them to the needs of your project. **Contextual Behaviors** allow you to manage cross-cutting concerns without rippling changes. **Cross-Project Refactoring** extends tooling support for common refactoring tasks to work across project and library boundaries, without requiring manual effort.


### Extensible Modules with Cross-Project Refactoring

### The Right (Embedded) Language for the Job

## Concurrent by Default
Moore's law is dead. 

## Resilient Error Handling

## What's Next?
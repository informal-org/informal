import json

DEFAULT_CONTENT = json.dumps(
{
    "body": [
        {
            "id": "XP2NVY8Mu3z6bZJ6jHB84A",
            "name": "name",
            "expr": "\"World\"",
            "params": [],
            "docs": "Click to edit this cell and set the name variable to your name."
        },
        {
            "id": "ZEvtzsVVDmHsx6372HLEF3",
            "name": "intro",
            "expr": "\"Hello \" + name",
            "params": [],
            "docs": "You can reference other cells by their name. Cells in AppAssembly define declarative values and automatically update like spreadsheet cells. "
        },
        {
            "id": "gfTJJjBrinCKocVEkQB92",
            "name": "math_example",
            "expr": "(8 + 12) * 5",
            "params": [],
            "docs": ""
        },
        {
            "id": "HzYBdnCC29VySd87qbkMLb",
            "name": "task1",
            "expr": "0",
            "params": [],
            "docs": "Task: Compute the value of double math_example"
        },
        {
            "id": "FjfXJvAVbJmbGV4moFGZxi",
            "name": "",
            "expr": "task1 == 200",
            "params": [],
            "docs": ""
        },
        {
            "id": "xmYWm8sW74hH3tGSwnNDu3",
            "name": "arr",
            "expr": "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]",
            "params": [],
            "docs": "Define lists by enclosing values in []. Lists can contain data of multiple types."
        },
        {
            "id": "2M4PncCgYzLwBoUCmCFT52",
            "name": "brr",
            "expr": "[10, 20, .., 100]",
            "params": [],
            "docs": "You can also generate a sequence of values by listing out the first few entries and using .. to fill in the values. [1..10]"
        },
        {
            "id": "CwXsELkHNsXQUeNMwSm653",
            "name": "ten_k",
            "expr": "[1..10001]",
            "params": [],
            "docs": "Ranges are computed lazily, so they don't take extra memory."
        },
        {
            "id": "CcdcXfX3cJbScdUFdpJHK6",
            "name": "ten_k_sum",
            "expr": "sum(ten_k)",
            "params": [],
            "docs": ""
        },        
        {
            "id": "eFRgrtDfWLUsU3xHMsQwxD",
            "name": "double_arr",
            "expr": "arr * 2",
            "params": [],
            "docs": "AppAssembly supports Array programming so you can operate over the entire collection without loops."
        },
        {
            "id": "YLKGk43VkYsSNu3PJumvhj",
            "name": "indexing",
            "expr": "brr[2]",
            "params": [],
            "docs": "Select an element by index. Array indices start at 0."
        },
        {
            "id": "kgXMZE6mtEU4o8GZLwyPEa",
            "name": "even_indexes",
            "expr": "arr % 2 == 0",
            "params": [],
            "docs": "Indexing is a special case of filtering. You can pass a list of indexes or list of boolean flags to select a subset of an array."
        },
        {
            "id": "8kLdcSBkEqu6fiJAAtMVgN",
            "name": "arr_even",
            "expr": "arr[arr % 2 == 0]",
            "params": [],
            "docs": "You can combine filtering with array operations to easily slice and dice data."
        },
        {
            "id": "7qsFfMA5GVpH8Y6iDt3Ww5",
            "name": "greetings",
            "expr": "\"English\": \"Hello!\"\n\"Hindi\": \"नमस्ते\"\n\"Malayalam\": \"നമസ്കാരം\"\n\"Spanish\": \"Hola!\"\n\"Computer\": \"beep boop bop beep\"",
            "params": [],
            "docs": "Define key-value maps by using : to associate a key with a value."
        },
        {
            "id": "rB96mR3Srp3qd8HRu5jbPA",
            "name": "",
            "expr": "greetings[\"Computer\"]",
            "params": [],
            "docs": "Use map[key] to lookup the values."
        },
        {
            "id": "37vhDVLraqv9mdL9byCjE3",
            "name": "fibo",
            "expr": "1: 1\n2: 1\n(n): fibo(n-1) + fibo(n-2)",
            "params": [],
            "docs": "Functions are a mapping from some input to some output. Maps can contain elements that take in parameters and return a value."
        },
        {
            "id": "y4TLk9sJ556uNxvPB2bsy2",
            "name": "",
            "expr": "fibo(8)",
            "params": [],
            "docs": ""
        },
        {
            "id": "W2BGUnbjoLmSHT8cxyU7j4",
            "name": "fizzbuzz",
            "expr": "(x) if(x % 15 == 0): \"FizzBuzz\"\n(x) if(x % 3 == 0): \"Fizz\"\n(x) if(x % 5 == 0): \"Buzz\"\n(x): x",
            "params": [],
            "docs": "The keys can define guard clauses, which must pass for the key to match."
        },
        {
            "id": "YcXmNYBvk5bzfsD78CfSMH",
            "name": "",
            "expr": "[1..10].map(fizzbuzz)",
            "params": [],
            "docs": ""
        },
        {
            "id": "pyjAeoBQ8jjF9Bfcckn9t2",
            "name": "double",
            "expr": "0",
            "params": [],
            "docs": "Task: Write a function \"double\" which takes a number and doubles it."
        },
        {
            "id": "UDyJGdoK2KkLWGL5rp6HY4",
            "name": "",
            "expr": "double(10) == 20",
            "params": [],
            "docs": ""
        },        
        {
            "id": "EUK9yUGcrXjEsEhguCizk3",
            "name": "find_min",
            "expr": "(x, y): x",
            "params": [],
            "docs": "Task: Write a function \"min\" which takes in two numbers and returns the smaller of the two. Hint: Use the guard clauses and list out the cases. "
        },
        {
            "id": "mj5yHeeaVvHvpV8i7UGV92",
            "name": "",
            "expr": "find_min(10, 5) == 5",
            "params": [],
            "docs": ""
        },
        {
            "id": "E7Kxt393M9Uny9rbqBtKc8",
            "name": "movie",
            "expr": "title: \"Inception\"\nyear: 2010\ndirector: \"Christopher Nolan\"\nmusic: \"Hans Zimmer\"",
            "params": [],
            "docs": "Objects "
        },
        {
            "id": "Yc4npEu4ncjtnzdryspXjj",
            "name": "",
            "expr": "movie.title + \" (\" + movie.year + \")\"",
            "params": [],
            "docs": "Access object attributes with dot syntax."
        },
        {
            "id": "ZDtzrqKuwwgYraBfRsJLz3",
            "name": "cart",
            "expr": "items: [\"milk\", \"eggs\", \"sugar\"]\nprices: [2.70, 3.00, 4.97]\nquantity: [2, 1, 1]",
            "params": [],
            "docs": ""
        },
        {
            "id": "ZdokXa5gpUw7EYvH4upZH3",
            "name": "grand_total",
            "expr": "0",
            "params": [],
            "docs": "Task: Use the sum function and compute the grand total (prices * quantity) for the items in the cart."
        },
        {
            "id": "SMPGvrWRzwmAZ64HiT2J52",
            "name": "",
            "expr": "grand_total == 13.37",
            "params": [],
            "docs": ""
        },
        {
            "id": "xjfnWPjqbdrzFEHFDxU3C2",
            "name": "cart_filter",
            "expr": "cart.items",
            "params": [],
            "docs": "Task: Filter the cart elements whose item total is more than $4."
        },
        {
            "id": "UxPktz2Box33fesoLED3MC",
            "name": "",
            "expr": "all(cart_filter == [\"milk\", \"sugar\"])",
            "params": [],
            "docs": ""
        }
    ]
}
)

import json

DEFAULT_CONTENT = json.dumps({
    "body":[ {
        "id":0,
        "name":"Greeting",
        "input":"\"Hello World\""
    },
    {"id":1,
    "name":"response",
    "input": '"<h1>" + greeting + "</h1>"'},
    {"id":2,"name":"status_code","input":"100 * 2"}
]})
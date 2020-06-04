import json

DEFAULT_CONTENT = json.dumps(
    {
        "body":[
            {
                "id":"XP2NVY8Mu3z6bZJ6jHB84A",
                "name":"greeting",
                "expr":"\"Hello World\"",
                "params":[]
            },
            {
                "id":"ZEvtzsVVDmHsx6372HLEF3",
                "name":"status_code",
                "expr":"100 * 2",
                "params":[]
            },
            {
                "id":"gfTJJjBrinCKocVEkQB92",
                "name":"response",
                "expr":"\"<h1>\" + greeting + \"</h1>\"",
                "params":[]
            }
        ]
    }
)

var esprima = require('esprima');
const util = require('util');


var program = `
var a = 1; var two = 3;
var b = 2;

var c = a + b;
`

const TYPE_CELL = "CELL"


class Cell {
    constructor(id, name="", expr="", params=[], body=[], parent=null){
        this.id = id;
        this.name = name;
        this.expr = expr;
        this.params = params;
        this.body = body;

        // Used internally for book-keeping and traversal
        this.parent = parent;
        this.depends_on = []
        this.used_by = []
        this.parsed = undefined;

        // Return values
        this.js = undefined;        // Constructed js code
        this.value = undefined;     // Resulting value after evaluation
        this.error = undefined;     // Any cell errors during evaluation
    }
}


var program = [
    {
        id: 1,
        type: TYPE_CELL,

        expr: "1 + 1",
        params: [],
        body: [],

        error: undefined,
        value: undefined,
        parsed: undefined,
        depends_on: [],
        used_by: []
    }
];

// expression
// children

// console.log("3")
// console.log(tokenized.body[2]);

function assignIds(parseTree, startId=0) {
    parseTree.body.forEach(element => {
        element.id = startId++;
        // TODO: Nested blocks - recurse along the path with the same IDs and return
    });
}

function sequentialize(parseTree) {
    // Takes a declarative parse tree and turns it into an imperative sequential equivalent
    
}

function serializeToJs(linearTree){
    // Takes a parse tree and emits a serialized javascript version of the program
}

function evaluate(serializedJs) {
    // Evaluates the generated js and returns the parse tree annotated with results
}

function run(){
    var tokenized = esprima.parse(program);
    // console.log(tokenized);
    assignIds(tokenized);

    console.dir(tokenized, { depth: null }); 
}

run();
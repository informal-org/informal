var esprima = require('esprima');
const util = require('util');


var program = `
var a = 1;
var b = 2;

var c = a + b;
`



var tokenized = esprima.parse(program);
// console.log(tokenized);
console.dir(tokenized, { depth: null }); 

// console.log("3")
// console.log(tokenized.body[2]);

function sequentialize(parseTree) {
    // Takes a declarative parse tree and turns it into an imperative sequential equivalent
}

function serializeToJs(parseTree){
    // Takes a parse tree and emits a serialized javascript version of the program
}


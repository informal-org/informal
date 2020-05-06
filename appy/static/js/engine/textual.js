var esprima = require('esprima');
const util = require('util');


var ROOT_ID = 0;

// All cells at all depths indexed by unique IDs
var byId = {
    1: {
        id: 1,
        name: "a",
        depends_on: [2, 3],     // Extracted from parse tree after name resolution.
        
        parent: ROOT_ID, // Reference to parent ID if not root
        body: [],
        params: []
    },
    2: {
        id: 2,
        name: "b",
        depends_on: [3],

        parent: ROOT_ID,
        body: [],
        params: []
    },
    3: {
        id: 3,
        name: "c",
        depends_on: [],

        parent: ROOT_ID,
        body: [],
        params: []
    }
}

var rootIds = [1, 2, 3];

// expression
// children

// console.log("3")
// console.log(tokenized.body[2]);

// TODO
function resolve(name, todo) {

}

function linearize(rootIds, byId) {
    // Takes a declarative parse tree and turns it into an imperative sequential equivalent
    // Input: List of {id: id, depends_on: []}.
    // Returns: {status: cycle/ok, path: [list of ids]}

    let eval_order = [];
    let leafs = [];
    
    // ID -> number of nodes that depend on it
    let depend_count = {};
    
    rootIds.forEach(id => {
        let node = byId[id];
        if(node.depends_on.length == 0) {
            leafs.push(id);
        } else {
            depend_count[id] = node.depends_on.length;
        }
    });

    while(leafs.length > 0) {
        let leaf = leafs.shift();   // Pop first leaf
        eval_order.push(leaf);

        // Remove it as an unmet dependency for all its child elements.
        leaf.used_by.forEach((dependent_id) => {
            if(dependent_id in depend_count) {
                depend_count[dependent_id] -= 1;
                if(depend_count[dependent_id] == 0) {
                    // Remove nodes without any dependencies
                    delete depend_count[dependent_id]
                    leafs.push(dependent_id);
                }
            } else {
                leafs.push(dependent_id)
            }
        })
    }
    // No more leaf nodes without any dependencies. All remaining nodes are interdependent.
    return {
        cycle: Object.keys(depend_count),
        order: eval_order
    }
}

function serializeToJs(linearTree){
    // Takes a parse tree and emits a serialized javascript version of the program
}

function evaluate(serializedJs) {
    // Evaluates the generated js and returns the parse tree annotated with results
}

function inspect() {

}

function run(){
    var tokenized = esprima.parse(program);
    // console.log(tokenized);
    assignIds(tokenized);

    console.dir(tokenized, { depth: null }); 
}

run();
var esprima = require('esprima');
const util = require('util');

const hamt = require('hamt');   // Hash array mapped trie - immutable map


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

function generateScopeMap(rootId, byId, scopesById) {
    // rootID = ID of current node being traversed.
    // byId = Cell map by id.
    // scopesById: MUTABLE map of global scope at each point in the tree.
    // Compute the scope at each point and store in an efficient structure for name resolution
    
    var cell = byId[rootId];
    if(cell.parent) {
        // Initialize the scope to the parent scope at this point in iteration
        // assert: scopesById[global root] = empty hamt map.
        scopesById[rootId] = scopesById[cell.parent];
    }

    // Add parameters to scope.
    for(var i = 0; i < cell.params.length; i++) {
        scopesById[rootId] = scopesById[rootId].set(param.name, param.id);
    }

    // The scope's name itself will be defined in the parent scope.

    // Child scopes : Function body / arrays / objects
    for(var i = 0; i < cell.body.length; i++) {
        let child = cell.body[i];
        // Note that scopesById changes over the course of the definition.
        createScopeMap(child.id, byId, scopesById)
        
        // Finish processing this tree by adding it to the current scope
        if(child.name) {
            // Set and overwrite any previous name bindings to support aliasing.
            scopesById[rootId] = scopesById[rootId].set(child.name, child.id)
        }
    }

    // scopesById at this point has the node and all child scopes defined.
}

// TODO
function resolve(name, refCellId, byId) {
    // Given a name, identify which node it's referencing by scope rules.    
    
    // First check in the parameters.
    while(true) {
        var refCell = byId[refCellId];
        // Check function parameters if it's a function
        if(refCell.params) {
            for(var i = 0; i < refCell.params.length; i++) {
                var param = refCell.params[i];
                if(param === name) {
                    return {
                        type: TYPE_PARAM, 
                        cell: refCellId
                    }    
                }
            }    
        }

    }

}

function linearize(rootIds, byId, metDeps) {
    // Takes a declarative parse tree and turns it into an imperative sequential equivalent
    // Input: List of {id: id, depends_on: []}. metDeps = Set of dependencies met outside of this node.
    // Returns: {status: cycle/ok, path: [list of ids]}

    let eval_order = [];
    let child_order = {};
    let leafs = [];

    // Clone the met dependency for internal use without mutating the parameter.
    metDeps = Set(metDeps.values());
    
    // ID -> number of nodes that depend on it
    let depend_count = {};
    
    rootIds.forEach(id => {
        let node = byId[id];
        let unmet_dependency_count = 0;

        // Count unmet dependencies excluding nodes in met dependencies set.
        node.depends_on.forEach((dependency_id) => {
            if(!metDeps.has(dependency_id)) {
                unmet_dependency_count++;
            }
        })

        if(unmet_dependency_count == 0) {
            leafs.push(id);
        } else {
            depend_count[id] = unmet_dependency_count;
        }
    });

    while(leafs.length > 0) {
        let leaf_id = leafs.shift();   // Pop first leaf
        let leaf = byId[leaf_id];
        eval_order.push(leaf_id);
        metDeps.add(leaf_id);

        // Linearize any sub-scopes (i.e. function body)
        // Assume: No parent-child cycles or this would lead to infinite recursion.
        // Prevented by the language.
        if(leaf.children) {
            child_order[leaf_id] = linearize(leaf.children, byId, metDeps)
        }

        // Remove it as an unmet dependency for everything depending on it.
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
        });


    }
    // No more leaf nodes without any dependencies. All remaining nodes are interdependent.
    return {
        cycles: Object.keys(depend_count),
        order: eval_order,
        children: child_order
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

export function add(a, b) {
    return a + b
}
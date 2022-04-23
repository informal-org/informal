import { traverseDown, traverseUp } from "@informal/shared/iter.js";
const hamt = require('hamt');


export function defineNamespace(cell) {
    // Trace through child nodes and define reachable names at each point in the tree
    
    // Initialize to the *current*, partial parent namespace.
    if(cell.parent) {
        cell.namespace = cell.parent.namespace;
    }

    // Bind all params and child nodes to current state.
    traverseDown(cell, defineNamespace);

    // Bind name, overwrite any previous name bindings to support aliasing.
    if(cell.name && cell.parent) {
        cell.parent.namespace = cell.parent.namespace.set(cell.name, cell)
    }
};

export function resolve(cell, name) {
    let directRef = cell.namespace.get(name);
    if(directRef) {
        return directRef;
    }
    return traverseUp(cell, resolve, name)
}

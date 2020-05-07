const hamt = require('hamt');

class Cell {
    constructor(cell, parent, byId) {
        this.parent = parent;
        this.id = cell.id;
        this.type = cell.type;
        this.name = cell.name;
        this.expr = cell.expr;
        var currentCell = this;
        // Cell is the only parent for params and body, so recursively init those.
        this.params = cell.params.map((param) => new Cell(param, currentCell, byId));
        this.body = cell.body.map((bodyCell) => new Cell(bodyCell, currentCell, byId));
        // Additional computed metadata
        this.depends_on = [];
        this.used_by = [];
        this.parsed = {};

        this.namespace = hamt.empty;
    }

    defineNamespace() {
        // Trace through child nodes and define reachable names at each point in the tree
        
        // Initialize to the current parent namespace.
        if(this.parent) {
            this.namespace = this.parent.namespace;
        }

        // Early binding of all parameters and child nodes defined incrementally.
        // This namespace doesn't contain all of the names - it's missing anything declared after.
        // These are resolved lazily late when called.

        // Add parameters to scope
        this.params.forEach((param) => {
            // Params can reference parent scope or previously defined params
            // for default values, but not the function body.
            param.defineNamespace();
            this.namespace = this.namespace.set(param.name, param);
        })

        this.body.forEach((child) => {
            // Define the child scope relative to this current scope at this point in time.
            child.defineNamespace();

            // Set and overwrite any previous name bindings to support aliasing.
            if(child.name) {
                this.namespace = this.namespace.set(child.name, child);
            }
        });
    }

    resolve(name) {
        // First check in namespace for any aliased names.
        let directRef = this.namespace.get('name');
        if(directRef) {
            return directRef;
        }

        // Check up the scopes for any names defined afterwards.
        // Save result for future since the tree never changes and resolution is static.
        if(this.parent) {
            let parentRef = this.parent.resolve(name);
            if(parentRef) {
                this.namespace = this.namespace.set(name, parentRef);
                return parentRef
            }
        }

        // Not found in any scope
        return undefined;
    }
}

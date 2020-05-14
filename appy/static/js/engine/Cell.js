const hamt = require('hamt');

export class Cell {
    constructor(cell, parent, byId) {
        this.parent = parent;
        this.id = cell.id;
        this.type = cell.type;
        this.name = cell.name;
        this.expr = cell.expr;
        var currentCell = this;

        // Cell is the only parent for params and body, so recursively init those.
        this.params = cell.params.map((param) => new Cell(byId[param], currentCell, byId));
        this.body = cell.body.map((bodyCell) => new Cell(byId[bodyCell], currentCell, byId));

        // Mutable execution state.
        this._eval_order = [];
        this._depend_count = undefined;
        this._cycles = new Set();

        // Additional computed metadata
        this.depends_on = new Set()
        this.used_by = new Set()
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

    addDependency(cell) {
        this.depends_on.add(cell);
        cell.used_by.add(this);
    }

    removeDependency(cell) {
        // Assert: Caller ensures that cell has no further dependencies on this.
        this.depends_on.delete(cell);
        cell.used_by.delete(this);
    }

    orderByDeps(metDeps) {
        // metDeps = set of references
        this._eval_order = [];
        let leafs = []; // Leafs are cells with all dependencies met & are ready to be evaluated.
        let pending_nodes = new Set();

        // Clone met deps for internal use without mutating shared one
        // metDeps = new Set(metDeps.values());

        this.body.forEach((cell) => {
            if(cell.countUnmetDeps(metDeps) === 0) {
                leafs.push(cell);
            } else {
                pending_nodes.add(cell);
            }
        })

        // Mark each leaf cell for execution and update book-keeping
        while(leafs.length > 0) {
            let leaf = leafs.shift();   // Pop first leaf
            this._eval_order.push(leaf);
            metDeps.add(leaf);

            // Linearize any sub-scopes
            // Assume: No parent cycles (prevented by lang semantics) or this can be an infinite loop
            if(leaf.body) {
                leaf.orderByDeps(metDeps);
            }

            leaf.used_by.forEach((dependent) => {
                // Mark dep as met. If it's a child, queue it up for execution.
                if(dependent.decUnmetDeps(metDeps) === 0 && pending_nodes.has(dependent)) {
                    leafs.push(dependent);
                    pending_nodes.delete(dependent);
                }
            })
        }

        console.log(pending_nodes);
        // All remaining pending nodes are interdependent.
        this._cycles = pending_nodes;
    }

    countUnmetDeps(metDeps) {
        let unmet_dependency_count = 0;
        this.depends_on.forEach((dep) => {
            if(!metDeps.has(dep)) {
                unmet_dependency_count++;
            }
        })
        this._depend_count = unmet_dependency_count;
        return this._depend_count;
    }

    decUnmetDeps(metDeps) {
        if(this._depend_count === undefined) {
            this.countUnmetDeps(metDeps);
        } else {
            this._depend_count -= 1;
        }
        return this._depend_count;
    }

    toString() {
        return "Cell(" + this.id + ")";
    }

}

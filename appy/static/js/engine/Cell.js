const hamt = require('hamt');

export class Cell {
    constructor(cell, parent, env) {
        env.cell_map[cell.id] = this;
        this.env = env;
        this.parent = parent;

        this.id = cell.id;
        this.type = cell.type;
        this.name = cell.name;
        this.expr = cell.expr;

        let currentCell = this;

        // Cell is the only parent for params and body, so recursively init those.
        this.param_ids = new Set(cell.params);
        this.params = cell.params.map((param) => {
            return new Cell(env.getRawCell(param), currentCell, env)
        });
        
        this.body_ids = new Set(cell.body);
        this.body = cell.body.map((bodyCell) => {
            return new Cell(env.getRawCell(bodyCell), currentCell, env)
        });

        // Mutable execution state.
        this._num_pending_deps = undefined;
        // Numerical index of evaluation order in total ordering
        this._eval_index = undefined;

        this.parsed = {};
        this.namespace = hamt.empty;

        cell.depends_on.forEach((dep) => {
            env.addDependency(cell.id, dep)
        })
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

            if(param.name) {
                this.namespace = this.namespace.set(param.name, param);
            }
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
        let directRef = this.namespace.get(name);
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

    toString() {
        return "Cell(" + this.id + "," + this.name + ")";
    }
}

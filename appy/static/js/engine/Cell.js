const hamt = require('hamt');
import { union, difference, Queue } from "../utils.js"

export class Environment {
    // Cells live in a shared environment. 
    // Contains mappings and functionality at the intersection of cells.
    
    constructor(raw_map) {
        this.cell_map = {};
        
        // Raw details by map
        this.raw_map = raw_map;

        // Cell ID -> Set of dependencies
        // Use maps for these instead of Cell attributes
        // so they can be defined independent of cell creation order
        this.dependency_map = {};
        this.usage_map = {};

        this.eval_order = [];
        this.cyclic_cells = new Set();

        // Cell ID -> subset of dep map that's cyclic
        this.cyclic_deps = {};
    }

    static getDefaultSet(map, key) {
        // Lookup key in map with python defaultdict like functionality.
        if(!map.hasOwnProperty(key)) {
            map[key] = new Set();
        } 
        return map[key]
    }

    addDependency(cell_id, dep_id) {
        let dep_set = Environment.getDefaultSet(this.dependency_map, cell_id);
        dep_set.add(dep_id);

        // Add inverse relationship
        let usage_set = Environment.getDefaultSet(this.usage_map, dep_id);
        usage_set.add(cell_id)
    }

    getRawCell(id) {
        return this.raw_map[id]
    }

    getCell(id) {
        return this.cell_map[id]
    }

    getDependsOn(cell_id) {
        return Environment.getDefaultSet(this.dependency_map, cell_id)
    }

    getUsedBy(cell_id) {
        return Environment.getDefaultSet(this.usage_map, cell_id)
    }

    totalOrderByDeps() {
        let leafs = new Queue(); // Leafs are cells with all dependencies met & are ready to be evaluated.
        let pending_nodes = new Set();
        let eval_order = new Array();

        // Clone met deps for internal use without mutating shared one
        // metDeps = new Set(metDeps.values());
        Object.values(this.cell_map).forEach((cell) => {
            cell._eval_index = undefined;
            cell._depend_count = this.getDependsOn(cell.id).size
            if(cell._depend_count === 0) {
                leafs.push(cell);
            } else {
                pending_nodes.add(cell);
            }
        })

        // Mark each leaf cell for execution and update book-keeping
        while(leafs.length > 0) {
            let leaf = leafs.shift();
            eval_order.push(leaf);

            this.getUsedBy(leaf.id).forEach((dep_id) => {
                let dependent = this.getCell(dep_id);
                // Mark dep as met. If it's a child, queue it up for execution.
                if(dependent._depend_count === 0) {
                    leafs.push(dependent);
                    pending_nodes.delete(dependent);
                }
            })
        }

        // All remaining nodes at this point are interdependent cycles
        this.cyclic_cells = pending_nodes;
        this.eval_order = eval_order;

        // Mark each node with its execution order for local sorting when generating code
        this.eval_order.forEach((cell, index) => {
            cell._eval_index = index;
        })

        this.cyclic_ids = Array.from(this.cyclic_cells).map(cell => cell.id)
        this.cyclic_cells.forEach((cell) => {
            // Find which of cell's dependencies are cyclic
            this.cyclic_deps[cell.id] = intersection(this.getDependsOn(cell.id), this.cyclic_ids)
        })
    }
}


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
            new Cell(env.getRawCell(param), currentCell, env)
        });
        
        this.body_ids = new Set(cell.body);
        this.body = cell.body.map((bodyCell) => {
            new Cell(env.getRawCell(bodyCell), currentCell, env)
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

    toString() {
        return "Cell(" + this.id + "," + this.name + ")";
    }
}

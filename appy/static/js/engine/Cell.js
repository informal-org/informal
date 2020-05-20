const hamt = require('hamt');
import { union, difference } from "../utils.js"

export class Cell {
    constructor(cell, parent, byId, cellMap) {
        cellMap[cell.id] = this;
        this.cellMap = cellMap;
        this.parent = parent;
        this.id = cell.id;
        this.type = cell.type;
        this.name = cell.name;
        this.expr = cell.expr;

        let currentCell = this;

        // Cell is the only parent for params and body, so recursively init those.
        this.param_ids = Set(cell.params);
        this.params = cell.params.map((param) => {
            new Cell(byId[param], currentCell, byId, cellMap)
        });
        
        this.body_ids = Set(cell.body);
        this.body = cell.body.map((bodyCell) => {
            new Cell(byId[bodyCell], currentCell, byId, cellMap)
        });

        // Mutable execution state.
        this._num_pending_deps = undefined;

        // Additional computed metadata. 
        // ID of dependencies and computed inverse relationship
        this.depends_on = new Set(cell.depends_on)
        this.used_by = new Set(cell.used_by)

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

    addReference(cellId) {
        this.references.add(cellId);
    }

    removeReference(cellId) {
        // Assert: Caller ensures that cell has no further dependencies on this.
        this.references.delete(cellId);
    }

    markDependsOn() {
        // Definition: A node depends on sibling and parent/external nodes
        // But not on any descendant nodes

        // Set of parent references minus all child references
        if(this.body) {
            // With a body, external references are sum of child refs - child refs
            let external_deps = this.references;

            let internal_deps = union(this.body_ids, this.param_ids)
            
            // Compute sum of external deps for all children
            this.params.forEach((cell) => {
                // Params don't have any body, so skip the call
                external_deps = union(external_deps, cell.references)
            });

            // Assume: No cycles between parent-body.
            this.body.forEach((cell) => {
                external_deps = union(external_deps, cell.markDependencies())
            });

            // Remove internal deps
            external_deps = difference(external_deps, internal_deps)
            
            this.depends_on = external_deps
            return deps
        } else {
            // Without a body, everything it references is external
            this.depends_on = deps
            return this.references
        }
    }

    markUsedBy() {

    }

    static markDependencies(depMap, cellMap) {
        // assert: all cells have a clean list of depends_on and used_by
        // If a node has child nodes, its dependencies should include all of its child deps 
        // minus any internal interdependence. 
        // Child nodes can then execute with local ordering (assume all parent deps met)

        Object.values(depMap).forEach((cellMeta) => {
            let cell = cellMap[cellMeta.id]
            cellMeta.depends_on.forEach((depId) => {
                let dep = cellMap[depId];
                cell.addDependency(dep);
            })
        })
    }

    static totalOrderByDeps(cellMap) {
        // Assert: cellMap is a sub-graph or total graph that contain all interdependencies
        let leafs = []; // Leafs are cells with all dependencies met & are ready to be evaluated.
        let pending_nodes = new Set();
        let eval_order = new Array();
        let met_deps = new Set();

        // Clone met deps for internal use without mutating shared one
        // metDeps = new Set(metDeps.values());
        Object.values(cellMap).forEach((cell) => {
            cell._depend_count = cell.depends_on.size
            if(cell._depend_count === 0) {
                leafs.push(cell);
            } else {
                pending_nodes.add(cell);
            }
        })

        // Mark each leaf cell for execution and update book-keeping
        while(leafs.length > 0) {
            let leaf = leafs.shift();   // Pop first leaf
            eval_order.push(leaf);
            met_deps.add(leaf);

            leaf.used_by.forEach((dependent) => {
                // Mark dep as met. If it's a child, queue it up for execution.
                if(dependent._depend_count === 0) {
                    leafs.push(dependent);
                    pending_nodes.delete(dependent);
                }
            })
        }

        // All remaining pending nodes are interdependent cycles
        return {
            'order': eval_order,
            'cycles': pending_nodes
        }
    }

    toString() {
        return "Cell(" + this.id + "," + this.name + ")";
    }

}

import { intersection } from "../utils";
import { Queue } from "../utils";

export class CellEnvironment {
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
        if (!map.hasOwnProperty(key)) {
            map[key] = new Set();
        }
        return map[key];
    }
    addDependency(cell_id, dep_id) {
        let dep_set = CellEnvironment.getDefaultSet(this.dependency_map, cell_id);
        dep_set.add(dep_id);
        // Add inverse relationship
        let usage_set = CellEnvironment.getDefaultSet(this.usage_map, dep_id);
        usage_set.add(cell_id);
    }
    getRawCell(id) {
        return this.raw_map[id];
    }
    getCell(id) {
        return this.cell_map[id];
    }
    getDependsOn(cell_id) {
        return CellEnvironment.getDefaultSet(this.dependency_map, cell_id);
    }
    getUsedBy(cell_id) {
        return CellEnvironment.getDefaultSet(this.usage_map, cell_id);
    }
    totalOrderByDeps() {
        let leafs = new Queue(); // Leafs are cells with all dependencies met & are ready to be evaluated.
        let pending_nodes = new Set();
        let eval_order = new Array();
        // Clone met deps for internal use without mutating shared one
        // metDeps = new Set(metDeps.values());
        Object.values(this.cell_map).forEach((cell) => {
            cell._eval_index = undefined;
            cell._depend_count = this.getDependsOn(cell.id).size;
            if (cell._depend_count === 0) {
                leafs.push(cell);
            }
            else {
                pending_nodes.add(cell);
            }
        });
        // Mark each leaf cell for execution and update book-keeping
        while (leafs.length > 0) {
            let leaf = leafs.shift();
            eval_order.push(leaf);
            this.getUsedBy(leaf.id).forEach((dep_id) => {
                let dependent = this.getCell(dep_id);
                dependent._depend_count -= 1;
                // Mark dep as met. If it's a child, queue it up for execution.
                if (dependent._depend_count === 0) {
                    leafs.push(dependent);
                    pending_nodes.delete(dependent);
                }
            });
        }
        // All remaining nodes at this point are interdependent cycles
        this.cyclic_cells = pending_nodes;
        this.eval_order = eval_order;
        // Mark each node with its execution order for local sorting when generating code
        this.eval_order.forEach((cell, index) => {
            cell._eval_index = index;
        });
        this.cyclic_ids = new Set(Array.from(this.cyclic_cells).map(cell => cell.id));
        this.cyclic_cells.forEach((cell) => {
            // Find which of cell's dependencies are cyclic
            this.cyclic_deps[cell.id] = intersection(this.getDependsOn(cell.id), this.cyclic_ids);
        });
    }
}

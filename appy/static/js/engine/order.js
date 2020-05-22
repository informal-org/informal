import { intersection } from "../utils";
import { Queue } from "../utils";

export function addDependency(env, cell_id, dep_id) {
    let dep_set = env.getDependsOn(cell_id);
    dep_set.add(dep_id);

    // Add inverse relationship
    let usage_set = env.getUsedBy(dep_id);
    usage_set.add(cell_id);
}

export function totalOrderByDeps(env) {
    // Performs a total ordering of all cells in environment.

    // Leafs are cells with all dependencies met & are ready to be evaluated.
    let leafs = new Queue();
    let pending_nodes = new Set();
    let eval_order = new Array();

    // Clone met deps for internal use without mutating shared one
    // metDeps = new Set(metDeps.values());
    Object.values(env.cell_map).forEach((cell) => {
        cell._eval_index = undefined;
        cell._depend_count = env.getDependsOn(cell.id).size;
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
        env.getUsedBy(leaf.id).forEach((dep_id) => {
            let dependent = env.getCell(dep_id);
            dependent._depend_count -= 1;
            // Mark dep as met. If it's a child, queue it up for execution.
            if (dependent._depend_count === 0) {
                leafs.push(dependent);
                pending_nodes.delete(dependent);
            }
        });
    }
    
    // All remaining nodes at this point are interdependent cycles
    let cyclic_cells = pending_nodes;
    env.eval_order = eval_order;

    // Mark each node with its execution order for local sorting when generating code
    env.eval_order.forEach((cell, index) => {
        cell._eval_index = index;
    });
    
    env.cyclic_deps = {};
    let cyclic_ids = new Set(Array.from(cyclic_cells).map(cell => cell.id));
    cyclic_cells.forEach((cell) => {
        // Find which of cell's dependencies are cyclic
        env.cyclic_deps[cell.id] = intersection(env.getDependsOn(cell.id), cyclic_ids);
    });
}
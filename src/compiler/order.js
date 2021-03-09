import { intersection } from "@appassembly/shared";
import { Queue } from "@appassembly/shared";

export function addDependency(env, cell_id, dep_id) {
    let dep_set = env.getDependsOn(cell_id);
    dep_set.add(dep_id);

    // Add inverse relationship
    let usage_set = env.getUsedBy(dep_id);
    usage_set.add(cell_id);
}


export function getReferences(node, context) {
    /* Parse through an expression tree and return list of dependencies */

    switch(node.node_type) {
        case "binary":
            let left = getReferences(node.left, context);
            let right = getReferences(node.right, context);
            // TODO: Check op. If == '.' - do resolve member
            return left.concat(right)
        case "unary":
            return getReferences(node.left, context)
        case "(literal)":
            return []
        case "(identifier)":
            // TODO: Check built in symbols
            let resolution = resolve(context)
            // TODO: name lookup

            // return [id_resolution]
        case "maplist":
            // For each element in node.value
        case "map":
            // node.value
        case "apply":
            // Resolve each argument
        default:
            console.log("Could not find refs for ast node:");
            console.log(node);
    }

}


export function orderCellBody(cell) {
    // Convert total ordering to local ordering by
    // re-ordering the cell body by its _eval_index
    if(cell.ordered_body.length > 0) {
        return cell.ordered_body
    }
    // Shallow copy of cell body
    cell.ordered_body = Array.from(cell.body);
    // In place sort by eval_index. Ascending.
    cell.ordered_body.sort((a, b) => a._eval_index - b._eval_index)
    return cell.ordered_body
}


function partitionByDeps(env, ready_cells, pending_cells) {
    // Partition the list into leafs whose dependencies have been met
    // and pending nodes with pending unmet dependencies.

    Object.values(env.cell_map).forEach((cell) => {
        cell._eval_index = undefined;
        cell._depend_count = env.getDependsOn(cell.id).size;
        if (cell._depend_count === 0) {
            ready_cells.push(cell);
        }
        else {
            pending_cells.add(cell);
        }
    });
}

function markEvalOrder(env, eval_order) {
    env.eval_order = eval_order;

    // Mark each node with its execution order for local sorting when generating code
    env.eval_order.forEach((cell, index) => {
        cell._eval_index = index;
    });
}

function markCyclicDeps(env, cyclic_cells) {
    env.cyclic_deps = {};
    let cyclic_ids = new Set(Array.from(cyclic_cells).map(cell => cell.id));
    cyclic_cells.forEach((cell) => {
        // Find which of cell's dependencies are cyclic
        env.cyclic_deps[cell.id] = intersection(env.getDependsOn(cell.id), cyclic_ids);
    });

}

export function totalOrderByDeps(env) {
    // Performs a total ordering of all cells in environment using
    // Kahn's topological sort algorithm.
    let ready_cells = new Queue();  // Cells with all dependencies met. Ready for eval.
    let pending_cells = new Set();  // Cells with pending unmet dependencies.
    let eval_order = new Array();

    partitionByDeps(env, ready_cells, pending_cells);

    // Mark each leaf cell for execution and update book-keeping
    while (ready_cells.length > 0) {
        let cell = ready_cells.shift();
        eval_order.push(cell);
        env.getUsedBy(cell.id).forEach((dep_id) => {
            let dependent = env.getCell(dep_id);
            dependent._depend_count -= 1;
            // Mark dep as met. If it's a child, queue it up for execution.
            if (dependent._depend_count === 0) {
                ready_cells.push(dependent);
                pending_cells.delete(dependent);
            }
        });
    }
    
    markEvalOrder(env, eval_order);
    
    // All remaining nodes at this point are interdependent cycles
    markCyclicDeps(env, pending_cells)
}
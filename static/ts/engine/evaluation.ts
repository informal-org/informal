import { Value } from "./engine";
import {ValueError} from "./errors";

export function getEvalOrder(cells: Value[]){
    /*
    Perform a topological sort of the node dependencies to get the evaluation order.
    */

    let eval_order: Value[] = [];
    let leafs: Value[] = [];
    // Value -> # of nodes that depend on it.
    let depend_count: {
        [index: string]: number
    } = {};

    cells.forEach(cell => {
        if(cell.depends_on.length === 0){
            leafs.push(cell);
        } else {
            depend_count[cell.id] = cell.depends_on.length;
        }
    });

    while(leafs.length > 0) {
        let cell = leafs.shift();   // Pop first element
        if(cell != undefined){  // Unnecessary check to appease typescript.
            eval_order.push(cell);
            cell.used_by.forEach(cell_user => {
                if(cell_user.id in depend_count){
                    depend_count[cell_user.id] -= 1;
                    if(depend_count[cell_user.id] <= 0){
                        // Remove nodes without any dependencies
                        delete depend_count[cell_user.id]
                    }
                }
                // This should not be turned into an else.
                // The item may have been removed in previous branch.
                if(!(cell_user.id in depend_count)){
                    // Add nodes whose dependencies are now met.
                    leafs.push(cell_user)
                }
            })
        }
    }
    let unmet_dependencies = Object.keys(depend_count);
    if(unmet_dependencies.length > 0){
        let cell_id_map: {
            [index: string]: Value
        } = {};

        cells.forEach((cell) => {
            cell_id_map[cell.id] = cell;
        });

        let unmet_cells: Value[] = unmet_dependencies.map((cell_id) => cell_id_map[cell_id]);
        let err: ValueError = new ValueError("Cycle detected");
        err.values = unmet_cells;
        throw err
    } else {
        return eval_order;
    }
}
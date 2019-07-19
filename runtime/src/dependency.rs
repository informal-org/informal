use std::collections::HashMap;
use std::collections::VecDeque;

use super::constants::*;
use super::structs::*;

// Dependency tree resolution

pub fn get_eval_order(cells: &mut Vec<ASTNode>) -> Vec<ASTNode> {
    // Perform a topological sort of the node dependencies to get the evaluation order
    // Errors on any cyclical dependencies

    let mut eval_order: Vec<ASTNode> = Vec::with_capacity(cells.len());
    // Use a VecDeque to efficiently get the first elements to preserve ordering
    let mut leafs: VecDeque<ASTNode> = VecDeque::with_capacity(cells.len());

    // ID -> Count
    let mut depend_count: HashMap<u64, ASTNode> = HashMap::with_capacity(cells.len());

    // Find leafs
    for mut cell in cells.drain(..) {
        let cell_dep_count = cell.depends_on.len();
        if cell_dep_count == 0 {
            leafs.push_back(cell);
        } else {
            cell.unmet_depend_count = (cell_dep_count as i32);
            depend_count.insert(cell.id, cell);
        }
    }

    // Iterate over leafs repeatedly building up eval order
    while let Some(leaf) = leafs.pop_front() {
        for cell_user_id in &leaf.used_by {
            // if depend_count.contains_key(&cell_user) {
            //     // Decrement and update count
            //     // depend_count.insert()
            // }

            if let Some(cell_user_ref) = depend_count.get_mut(&cell_user_id) {
                cell_user_ref.unmet_depend_count -= 1;
                if cell_user_ref.unmet_depend_count <= 0 {
                    // Remove nodes without any dependents. 
                    let cell_user_ref2 = depend_count.remove(&cell_user_id).unwrap();
                    leafs.push_back(cell_user_ref2);
                }


                // // TODO: This was moved inline. Verify if ok
                // // This should not be turned into an else. 
                // // The item may have been removed in previous branch.
                // if !depend_count.contains_key(&cell_user_id) {

                // }

            }
        }
        eval_order.push(leaf);
    }
    // TODO unmet dependency
    return eval_order
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_eval_order() {
        
    }
}
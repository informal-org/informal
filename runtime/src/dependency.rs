use avs::expression::Expression;
use fnv::{FnvHashMap, FnvHashSet};
use std::collections::VecDeque;

use avs::constants::{RUNTIME_ERR_CIRCULAR_DEP};
use std::rc::Rc;
use std::cell::RefCell;

use super::structs::*;

// Dependency tree resolution

pub fn get_eval_order(cells: &mut FnvHashMap<u64, Rc<RefCell<Expression>>>) -> Vec<Expression> {
    // Perform a topological sort of the node dependencies to get the evaluation order
    // Errors on any cyclical dependencies

    let mut eval_order: Vec<Expression> = Vec::with_capacity(cells.len());

    // Use a VecDeque to efficiently get the first elements to preserve ordering
    let mut leafs: VecDeque<Expression> = VecDeque::with_capacity(cells.len());

    // ID -> Count
    let mut depend_count: FnvHashMap<u64, Expression> = FnvHashMap::with_capacity_and_hasher(cells.len(), Default::default());

    // Find leafs
    for (_, cell_wrapper) in cells.drain() {
        let mut cell = Rc::try_unwrap(cell_wrapper).unwrap().into_inner();
        cell.unmet_depend_count = cell.depends_on.len() as i32;
        if cell.unmet_depend_count == 0 {
            leafs.push_back(cell);
        } else {
            depend_count.insert(cell.symbol, cell);
        }
    }

    // Iterate over leafs repeatedly building up eval order
    while let Some(leaf) = leafs.pop_front() {
        for cell_user_id in &leaf.used_by {
            // See if this leaf was the last user for it and it's now a leaf.
            if let Some(cell_user_ref) = depend_count.get_mut(&cell_user_id) {
                cell_user_ref.unmet_depend_count -= 1;
                if cell_user_ref.unmet_depend_count <= 0 {
                    // Remove nodes without any dependents. 
                    let cell_user_ref2 = depend_count.remove(&cell_user_id).unwrap();
                    leafs.push_back(cell_user_ref2);
                }
            }
        }

        eval_order.push(leaf);
    }
    
    // Mark any elements remaining with unmet dependencies as having circular dependencies.
    // TODO: Recursion support
    for (dep_count, mut unmet_dep) in depend_count.drain() {
        println!("Found unmet dep");
        // Only treat other cells/pointers as unmet dependency
        // Note that any depdency not present in the original cell list may be marked as unmet.
        unmet_dep.set_result(RUNTIME_ERR_CIRCULAR_DEP);
        eval_order.push(unmet_dep);
    }
    
    return eval_order
}

#[cfg(test)]
mod tests {
    use super::*;

    macro_rules! add_dep {
        ($a:expr, $b:expr) => ({
            $a.depends_on.push($b.symbol);
            $b.used_by.push($a.symbol);
        });
    }

    fn index_of(vec: &Vec<Expression>, target: &Expression) -> i32 {
        let mut i = 0;
        for node in vec {
            if node.symbol == target.symbol {
                return i
            }
            i += 1;
        }

        return i;        
    }

    macro_rules! create_test_expr {
        ($a:expr) => ({
            let mut e = Expression::new($a, String::from(""));
            e.symbol = $a;
            e
        });
    }


    // TODO: Implement this without Clone
    #[test]
    fn test_eval_order() {
        let mut a = create_test_expr!(1);
        let mut b = create_test_expr!(2);
        let mut c = create_test_expr!(3);
        let mut d = create_test_expr!(4);
        let mut e = create_test_expr!(5);
        let mut f = create_test_expr!(6);

    /*
    // #       a
    // #    b    c
    // #         d
    // #       e   f
    */

        add_dep!(a, b);
        add_dep!(a, c);
        add_dep!(c, d);
        add_dep!(d, e);
        add_dep!(d, f);

        let mut cells: FnvHashMap<u64, Expression> = FnvHashMap::default();
        cells.insert(a.symbol, a);
        cells.insert(b.symbol, b);
        cells.insert(c.symbol, c);
        cells.insert(d.symbol, d);
        cells.insert(e.symbol, e);
        cells.insert(f.symbol, f);
        
        let count = cells.len();
        let order = get_eval_order(&mut cells);

        println!("{:?}", order);

        // Assert everything returned
        assert_eq!(order.len(), count);
        // Expect ordered maintained. Doesn't matter if e is before or after f.

        assert_eq!(index_of(&order, &e) < index_of(&order, &d), true);
        assert_eq!(index_of(&order, &f) < index_of(&order, &d), true);
        assert_eq!(index_of(&order, &d) < index_of(&order, &c), true);
        assert_eq!(index_of(&order, &c) < index_of(&order, &a), true);
        assert_eq!(index_of(&order, &b) < index_of(&order, &a), true);
        // Node A should be evaluated last
        assert_eq!(index_of(&order, &a) == (order.len() as i32) - 1, true);
    }

}
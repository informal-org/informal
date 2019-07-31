use avs::utils::create_value_symbol;
// use std::collections::HashMap;
use fnv::FnvHashMap;
use super::dependency::{get_eval_order};
use super::structs::*;
use super::lexer::lex;
use super::parser::{apply_operator_precedence};
use avs::constants::{RUNTIME_ERR_UNK_VAL};



pub fn update_used_by(id64: &u64, ast_node: &mut Expression, node_list: &mut Vec<Expression>, node_map: &mut FnvHashMap<u64, usize>, 
used_by_buffer: &mut FnvHashMap<u64, Vec<u64>>) {
    // Build reverse side of the dependency map
    for dep in &ast_node.depends_on {
        if let Some(&dep_node_id) = node_map.get(&dep) {
            let dep_node = node_list.get_mut(dep_node_id).unwrap();
            dep_node.used_by.push(*id64);
        } else {
            // Queue it up to be added to the node when it's created
            if let Some(existing_queue) = used_by_buffer.get_mut(dep) {
                existing_queue.push(*id64);
            } else {
                let mut new_used_by_queue: Vec<u64> = Vec::new();
                new_used_by_queue.push(*id64);
                used_by_buffer.insert(*dep, new_used_by_queue);
            }
        }
    }

    // If this node has any buffered up used_by entries, save it.
    if used_by_buffer.contains_key(&ast_node.id) {
        ast_node.used_by = used_by_buffer.remove(&ast_node.id).unwrap();
    }
}



pub fn construct_ast(request: EvalRequest) -> Context {
    // let mut ast = AST::new();
    // let mut nodes: Vec<ASTNode> = Vec::with_capacity(request.body.len());
    // TODO: Define a root scope
    // ID -> Node
    let mut cell_list: Vec<Expression> = Vec::new();
    // Cell ID -> index of elem in node list above (because borrowing rules)
    let mut cell_index_map: FnvHashMap<u64, usize> = FnvHashMap::with_capacity_and_hasher(request.body.len(), Default::default());
    // For nodes that aren't fully created yet, store usages for later.
    let mut used_by_buffer: FnvHashMap<u64, Vec<u64>> = FnvHashMap::default();
    // Cell ID -> Internal Symbol ID for results
    let mut ast = Context::new(65000);
    ast.cell_symbols = Some(FnvHashMap::default());

    // The lexer already needs to know the meaning of symbols so it can create new ones
    // So it should just return used by as well in a single pass.
    for cell in request.body {
        let mut lexed = lex(&mut ast, &cell.input).unwrap();
        // Attempt to parse ID of cell and save result "@42" -> 42
        if let Some(id64) = cell.id[1..].parse::<u64>().ok() {
            let cell_symbol_value = ast.get_or_create_cell_symbol(id64);
            let mut ast_node = apply_operator_precedence(id64, &mut lexed);

            update_used_by(&cell_symbol_value, &mut ast_node, &mut cell_list, &mut cell_index_map, &mut used_by_buffer);

            cell_list.push(ast_node);
            cell_index_map.insert(cell_symbol_value, cell_list.len() - 1);
        } else {
            println!("ERROR parsing id {:?}", cell.id);
        }
        // TODO: ID Parsing failure? Or change the input format in a way that disallows failures
        // Or save an error node.
    }
    // Do a pass over all the nodes to resolve used_by. You could partially do this inline using a hashmap
    // Assert - used_by_buffer empty by now.

    ast.body = get_eval_order(&mut cell_list);
//    ast.cell_symbols = Some(cell_symbol_map);
    ast.symbols_index = cell_index_map;
    let node_len = cell_list.len();
    let mut values: Vec<u64> = Vec::with_capacity(node_len);
    for _ in 0..node_len {
        // If you dereference a value before it's set, it's an error
        values.push(RUNTIME_ERR_UNK_VAL);
    }
    ast.cell_results = values;
    return ast;
}
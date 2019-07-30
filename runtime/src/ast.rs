use avs::utils::create_value_symbol;
use std::collections::HashMap;
use super::dependency::{get_eval_order};
use super::structs::*;
use super::lexer::lex;
use super::parser::{apply_operator_precedence};
use avs::constants::{RUNTIME_ERR_UNK_VAL};



pub fn update_used_by(id64: &u64, ast_node: &mut ASTNode, node_list: &mut Vec<ASTNode>, node_map: &mut HashMap<u64, usize>, 
used_by_buffer: &mut HashMap<u64, Vec<u64>>) {
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



pub fn construct_ast(request: EvalRequest) -> AST {
    let mut ast = AST::new();
    // let mut nodes: Vec<ASTNode> = Vec::with_capacity(request.body.len());
    // ID -> Node
    let mut node_list: Vec<ASTNode> = Vec::new();
    // ID -> ID of elem in node list above (because borrowing rules)
    let mut node_map: HashMap<u64, usize> = HashMap::with_capacity(request.body.len());
    // For nodes that aren't fully created yet, store usages for later.
    let mut used_by_buffer: HashMap<u64, Vec<u64>> = HashMap::new();

    for cell in request.body {
        let mut lexed = lex(&cell.input).unwrap();
        // Attempt to parse ID of cell and save result "@42" -> 42
        if let Some(id64) = cell.id[1..].parse::<u64>().ok() {
            // TODO: Move the symbol reservation outside and change this to a check
            // if < rather than modifying the IDs around.
            let symbol_value: u64 = create_value_symbol( 65000 + id64 );
            let mut ast_node = apply_operator_precedence(symbol_value, &mut lexed);
            update_used_by(&symbol_value, &mut ast_node, &mut node_list, &mut node_map, &mut used_by_buffer);

            node_list.push(ast_node);
            node_map.insert(symbol_value, node_list.len() - 1);
        } else {
            println!("ERROR parsing id {:?}", cell.id);
        }
        // TODO: ID Parsing failure? Or change the input format in a way that disallows failures
        // Or save an error node.
    }
    // Do a pass over all the nodes to resolve used_by. You could partially do this inline using a hashmap

    // Assert - used_by_buffer empty by now.
    let node_len = node_list.len();

    ast.body = get_eval_order(&mut node_list);
    ast.scope.symbols = node_map;
    let mut values: Vec<u64> = Vec::with_capacity(node_len);
    for _ in 0..node_len {
        // If you dereference a value before it's set, it's an error
        values.push(RUNTIME_ERR_UNK_VAL);
    }
    ast.scope.values = values;
    return ast;
}
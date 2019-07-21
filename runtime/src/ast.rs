use std::collections::HashMap;
use super::dependency::{get_eval_order};
use super::structs::*;
use super::lexer::lex;
use super::parser::{apply_operator_precedence};

pub fn construct_ast(request: EvalRequest) -> Vec<ASTNode> {
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
            println!("Ok parsing id {:?}", id64);
            let mut ast_node = apply_operator_precedence(id64, &mut lexed);
            // Build reverse side of the dependency map
            for dep in &ast_node.depends_on {
                if let Some(dep_node_id) = node_map.get(&dep) {
                    // dep_node.used_by.push(id64);
                }
            }

            node_list.push(ast_node);
            node_map.insert(id64, node_list.len());
        } else {
            println!("ERROR parsing id {:?}", cell.id);
        }
        // TODO: ID Parsing failure? Or change the input format in a way that disallows failures
        // Or save an error node.
    }
    println!("nodes: {:?}", node_map);
    // Do a pass over all the nodes to resolve used_by. You could partially do this inline using a hashmap

    return get_eval_order(&mut node_list)
}
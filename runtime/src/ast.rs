use avs::runtime::BUILTIN_MODULES;
use avs::constants::APP_SYMBOL_START;
use avs::environment::Environment;
use avs::expression::Expression;
use fnv::FnvHashMap;
use super::dependency::{get_eval_order};
use super::structs::*;
use super::lexer::lex;
use super::parser::{apply_operator_precedence};
use avs::constants::{RUNTIME_ERR_UNK_VAL};



pub fn update_used_by(expr_map: &mut FnvHashMap<u64, Expression>, expr: &mut Expression) {
    // Build reverse side of the dependency map
    for dep in expr.depends_on.iter() {
        if let Some(&dep_node) = expr_map.get(&dep) {
            dep_node.used_by.push(expr.symbol);
        } else {
            // This shouldn't happen as we create all expression nodes in define_symbols
            panic!("Couldn't find the referenced dependency node");
        }
    }
}


pub fn define_symbols(request: &mut EvalRequest, ast: &mut Environment) -> FnvHashMap<u64, Expression> {
    // We may encounter these symbols and names while lexing, so do a pass to define names
    let expr_map: FnvHashMap<u64, Expression> = FnvHashMap::with_capacity_and_hasher(request.body.len(), Default::default());

    for cell in request.body.iter() {
        // Attempt to parse ID of cell and save result "@42" -> 42
        let mut node = Expression::new(cell.id, cell.input);
        node.symbol = ast.define_identifier();
        
        if cell.name.is_some() {
            let cell_name: &String = cell.name.as_ref().unwrap();
            let trimmed_name = cell_name.trim();
            if trimmed_name != "" {
                // Save the name
                let name_def_result = ast.bind_name(node.symbol, String::from(trimmed_name));
                // TODO: Handling duplicate names
            }
        }
        
        expr_map.insert(node.symbol, node);
    }
    return expr_map;
}

pub fn init_builtin(ast: &mut Environment) {
    // Initialize built in modules
    for m in BUILTIN_MODULES.iter() {
        // ast.define_cell_name(String::from(trimmed_name), cell_symbol_value);
    }
}


pub fn construct_ast(request: &mut EvalRequest) -> Environment {
    // let mut ast = AST::new();
    // let mut nodes: Vec<ASTNode> = Vec::with_capacity(request.body.len());
    // TODO: Define a root scope
    // // ID -> Node
    // let mut cell_list: Vec<Expression> = Vec::new();
    // // Cell ID -> index of elem in node list above (because borrowing rules)
    // let mut cell_index_map: FnvHashMap<u64, usize> = FnvHashMap::with_capacity_and_hasher(request.body.len(), Default::default());
    // // For nodes that aren't fully created yet, store usages for later.
    // let mut used_by_buffer: FnvHashMap<u64, Vec<u64>> = FnvHashMap::default();
    // Cell ID -> Internal Symbol ID for results
    
    let mut ast = Environment::new(APP_SYMBOL_START);
    let mut expr_map = define_symbols(&mut request, &mut ast);

    // At this point, we no longer need to deal with the raw request. 
    // Everything's in Environment.body

    // The lexer already needs to know the meaning of symbols so it can create new ones
    // So it should just return used by as well in a single pass.
    for expr in ast.body.iter() {
        let lex_result = lex(&mut ast, &expr.input);
        
        if lex_result.is_ok() {
            let mut lexed = lex_result.unwrap();
            apply_operator_precedence(&mut expr, &mut lexed);
            update_used_by(&mut expr_map, &mut expr);
        } else {
            expr.set_result(lex_result.err().unwrap());
        };
    }
    // Do a pass over all the nodes to resolve used_by. You could partially do this inline using a hashmap
    // Assert - used_by_buffer empty by now.

    ast.body = get_eval_order(&mut expr_map);
    // ast.cell_symbols = Some(cell_symbol_map);
    // ast.symbols_index = cell_index_map;
    // let node_len = cell_list.len();
    // let mut values: Vec<u64> = Vec::with_capacity(node_len);
    // for _ in 0..node_len {
    //     // If you dereference a value before it's set, it's an error
    //     values.push(RUNTIME_ERR_UNK_VAL);
    // }
    // ast.cell_results = values;
    return ast;
}

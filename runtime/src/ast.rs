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
use std::rc::Rc;
use std::cell::RefCell;


pub fn update_used_by(expr_map: &FnvHashMap<u64, Rc<RefCell<Expression>>>, expr: &Expression) {
    // Build reverse side of the dependency map
    for dep in expr.depends_on.iter() {
        if let Some(dep_node) = expr_map.get(dep) {
            dep_node.borrow_mut().used_by.push(expr.symbol);
        } else {
            // This shouldn't happen as we create all expression nodes in define_symbols
            panic!("Couldn't find the referenced dependency node");
        }
    }
}


pub fn define_symbols(request: &mut EvalRequest, ast: &mut Environment) -> FnvHashMap<u64, Rc<RefCell<Expression>>> {
    // We may encounter these symbols and names while lexing, so do a pass to define names
    let mut expr_map: FnvHashMap<u64, Rc<RefCell<Expression>>> = FnvHashMap::with_capacity_and_hasher(request.body.len(), Default::default());

    for cell in request.body.iter() {
        // Attempt to parse ID of cell and save result "@42" -> 42
        let mut node = Expression::new(cell.id, cell.input.clone());
        let symbol = ast.define_identifier();
        node.symbol = symbol;
        
        if cell.name.is_some() {
            let cell_name: &String = cell.name.as_ref().unwrap();
            let trimmed_name = cell_name.trim();
            if trimmed_name != "" {
                // Save the name
                let name_def_result = ast.bind_name(node.symbol, String::from(trimmed_name));
                // TODO: Handling duplicate names
            }
        }
        
        let wrapper = Rc::new(RefCell::new(node));

        expr_map.insert(symbol, wrapper);
    }
    return expr_map;
}

pub fn init_builtin(ast: &mut Environment) {
    // Initialize built in modules
    for m in BUILTIN_MODULES.iter() {
        // let ident = ast.define_identifier();
        ast.bind_name(m.symbol, m.name.to_string());
        ast.bind_value(m.symbol, m.value.clone());
        // ast.define_cell_name(String::from(trimmed_name), cell_symbol_value);
    }
}


pub fn construct_ast(mut request: &mut EvalRequest) -> Environment {
    let mut ast = Environment::new(APP_SYMBOL_START);
    init_builtin(&mut ast);

    let mut expr_map = define_symbols(&mut request, &mut ast);

    // The lexer already needs to know the meaning of symbols so it can create new ones
    // So it should just return used by as well in a single pass.
    for (mut id, mut expr_wrapper) in expr_map.iter() {
        let mut expr = expr_wrapper.borrow_mut();
        let lex_result = lex(&mut ast, &expr.input);
        
        if lex_result.is_ok() {
            let mut lexed = lex_result.unwrap();
            apply_operator_precedence(&mut expr, &mut lexed);
            update_used_by(&expr_map, &expr);
        } else {
            expr.set_result(lex_result.err().unwrap());
        };
    }

    let ordered = get_eval_order(&mut expr_map);
    ast.body = ordered;
    return ast;
}

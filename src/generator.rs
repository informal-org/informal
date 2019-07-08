#[macro_use]
use super::lexer::*;
use super::parser::*;

/*
// Takes parsed tokens and generates wasm code from it.
*/

pub const WASM_FBIN_ADD: &'static str  = "(f64.add)\n";
pub const WASM_FBIN_SUB: &'static str  = "(f64.sub)\n";
pub const WASM_FBIN_MUL: &'static str  = "(f64.mul)\n";
pub const WASM_FBIN_DIV: &'static str  = "(f64.div)\n";

pub const WASM_IBIN_AND: &'static str  = "(i32.and)\n";
pub const WASM_IBIN_OR: &'static str   = "(i32.or)\n";

// Not = val xor(1)
pub const WASM_IBIN_NOT: &'static str   = "(i32.const 1)(i32.xor)\n";

// alternatively. Do .nearest first
pub const WASM_F64_AS_I32: &'static str  = "(i32.trunc_s/f64)\n";

pub const WASM_I32_AS_F64: &'static str  = "(f64.convert_s/i32)\n";

/*
A standard list of type headers allowed for functions. 
By definition, WASM only allows a single return value.

t0: Void: () -> ()
t1: Main: () -> (i32) result code

# Boolean pattern of i32 = 0, f64 = 1
In future versions, this may be dynamically generated as-needed per program.
*/
pub const WASM_TYPE_HEADER: &'static str = r#"
(type $t0 (func))
(type $t1 (func (result i32)))
(type $t2 (func (result f64)))

(type $t3 (func (param i32)))
(type $t4 (func (param i32) (result i32)))
(type $t5 (func (param i32) (result f64)))

(type $t6 (func (param f64)))
(type $t7 (func (param f64) (result i32)))
(type $t8 (func (param f64) (result f64)))

(type $t9  (func (param i32) (param i32) ))
(type $t10 (func (param i32) (param i32) (result i32)))
(type $t11 (func (param i32) (param i32) (result f64)))

(type $t12 (func (param i32) (param f64) ))
(type $t13 (func (param i32) (param f64) (result i32)))
(type $t14 (func (param i32) (param f64) (result f64)))

(type $t15 (func (param f64) (param i32) ))
(type $t16 (func (param f64) (param i32) (result i32)))
(type $t17 (func (param f64) (param i32) (result f64)))

(type $t18 (func (param f64) (param f64) ))
(type $t19 (func (param f64) (param f64) (result i32)))
(type $t20 (func (param f64) (param f64) (result f64)))
"#;


/**
 * STD Function is_nan
 * Takes a floating point number and returns whether it's NaN. 
 * By definition, a NaN is not equal to itself. 
 * Return: 1 if nan, 0 otherwise.
 */
pub const WASM_FN_IS_NAN: &'static str = r#"
(func $is_nan (export "is_nan") (type $t1) (param $p0 f64) (result i32)
    get_local $p0
    get_local $p0
    f64.ne)
"#;

pub fn operator_to_wat(operator: KeywordType) -> String {
    let wasm_op: &str = match operator {
        KeywordType::KwPlus => {
            WASM_FBIN_ADD
        }
        KeywordType::KwMinus => {
            WASM_FBIN_SUB
        }
        KeywordType::KwMultiply => {
            WASM_FBIN_MUL
        }
        KeywordType::KwDivide => {
            WASM_FBIN_DIV
        }
        
        // TODO: Type checking of values?
        KeywordType::KwAnd => {
            WASM_IBIN_AND
        }
        KeywordType::KwOr => {
            WASM_IBIN_OR
        }
        KeywordType::KwNot => {
            WASM_IBIN_NOT
        }
        _ => {""}
    };
    return String::from(wasm_op);
}

pub fn ast_to_wat(node: ASTNode) -> String {
    match node.node_type {
        ASTNodeType::BinaryExpression => {
            let mut result: Vec<String> = vec![];
            // TODO: Validate order
            result.push(ast_to_wat(*node.left.unwrap()));
            result.push(ast_to_wat(*node.right.unwrap()));
            result.push(operator_to_wat(node.operator.unwrap()));

            return result.join("");
        }, 
        ASTNodeType::Literal => {
            match node.value.unwrap() {
                Value::Literal(LiteralValue::NumericValue(num)) => {
                    let lit_def = ["(f64.const ", &num.to_string(), ")"].concat();
                    
                    return lit_def;
                },
                Value::Literal(LiteralValue::BooleanValue(val)) => {    // val = 1 or 0
                    let lit_def = ["(i32.const ", &val.to_string(), ")"].concat();
                    return lit_def;
                },
                _ => {return String::from("");} // TODO
            }
        },
        _ => {
            // TODO
            return String::from("")
        }
    }
}


pub fn expr_to_wat(node: ASTNode) -> String {
    let header = String::from(r#"
(module
  "#);
  
    let fn_header = String::from(r#"
    (func $_start (type $t2) (result f64)
    "#);

    let mut body: Vec<String> = vec![];
    
    // Flag to trace whether the top of the stack if a float or an int for casting.
    let mut stackTopIsFloat = true;
    body.push(ast_to_wat(node));

    // for token in postfix {
    //     match &token {
    //         TokenType::Keyword(kw) => {

    //         }
    //         TokenType::Literal(lit) => {
    //             // TODO: Push the literal value
    //             match &lit {
    //             }
    //         },
    //         _ => {}
    //         // TODO
    //         // TokenType::Identifier(_id) => postfix.push(token),
    //     }
    // }

    if !stackTopIsFloat {
        body.push( WASM_I32_AS_F64.to_string() );
    }

    let footer = String::from(r#")
  (table 1 anyfunc)
  (memory $memory 0)
  (export "memory" (memory 0))
  (export "_start" (func $_start))
  )"#);

  return header + &String::from(WASM_TYPE_HEADER) + &fn_header + (&body.join("")) + &footer;
    
}


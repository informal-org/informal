#[macro_use]
use super::lexer::*;

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


pub fn expr_to_wat(postfix: Vec<TokenType>) -> String {
    let header = String::from(r#"
(module
  "#);
  
    let fn_header = String::from(r#"
    (func $main (type $t2) (result f64)
    "#);

    let mut body: Vec<String> = vec![];
    
    // Flag to trace whether the top of the stack if a float or an int for casting.
    let mut stackTopIsFloat = false;

    for token in postfix {
        match &token {
            TokenType::Keyword(kw) => {
                let wasm_op: &str = match kw {
                    KeywordType::KwPlus => {
                        stackTopIsFloat = true;
                        WASM_FBIN_ADD
                    }
                    KeywordType::KwMinus => {
                        stackTopIsFloat = true;
                        WASM_FBIN_SUB
                    }
                    KeywordType::KwMultiply => {
                        stackTopIsFloat = true;
                        WASM_FBIN_MUL
                    }
                    KeywordType::KwDivide => {
                        stackTopIsFloat = true;
                        WASM_FBIN_DIV
                    }
                    
                    // TODO: Type checking of values?
                    KeywordType::KwAnd => {
                        stackTopIsFloat = false;
                        WASM_IBIN_AND
                    }
                    KeywordType::KwOr => {
                        stackTopIsFloat = false;
                        WASM_IBIN_OR
                    }
                    KeywordType::KwNot => {
                        stackTopIsFloat = false;
                        WASM_IBIN_NOT
                    }
                    _ => {""}
                };
                body.push(String::from(wasm_op));
            }
            TokenType::Literal(lit) => {
                // TODO: Push the literal value
                match &lit {
                    LiteralValue::NumericValue(num) => {
                        let lit_def = ["(f64.const ", &num.to_string(), ")"].concat();
                        body.push( lit_def );
                        stackTopIsFloat = true;
                    },
                    LiteralValue::BooleanValue(val) => {    // val = 1 or 0
                        let lit_def = ["(i32.const ", &val.to_string(), ")"].concat();
                        body.push( lit_def );
                        stackTopIsFloat = false;
                    },
                    _ => {} // TODO
                }
            },
            _ => {}
            // TODO
            // TokenType::Identifier(_id) => postfix.push(token),
        }
    }

    if !stackTopIsFloat {
        body.push( WASM_I32_AS_F64.to_string() );
    }

    let footer = String::from(r#")
  (table 1 anyfunc)
  (memory $memory 0)
  (export "memory" (memory 0))
  (export "main" (func $main))
  )"#);

  return header + &String::from(WASM_TYPE_HEADER) + &fn_header + (&body.join("")) + &footer;
    
}


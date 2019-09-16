
#[cfg(test)]
mod tests {
    use super::*;
    use avs::constants::{SYMBOL_TRUE, SYMBOL_FALSE};
    use crate::interpreter;
    use crate::structs::*;
    use serde_json::json;
    use crate::lexer;
    use crate::parser;
    use crate::format;
    // use super::{decode_flatbuf};

    // pub use avs::avfb_generated::avfb::{get_root_as_av_fb_obj};
    pub use avs::structs::{AvObject, Runtime};

    macro_rules! read_eval {
        ($e:expr) => ({
            eval(read(String::from($e)))[0]
        });
    }

    macro_rules! read_eval_check {
        ($e:expr, $expected:expr) => ({
            // Execute both a compiled and interpreted version
            let i_result = interpreter::interpret_one(String::from($e));
            let context = Context::new(avs::constants::APP_SYMBOL_START);

            let fmt_interpreted = format::repr(&Runtime::new(18445899648779484648), &context, i_result);
            let fmt_expected = format::repr(&Runtime::new(18445899648779484648), &context, $expected);
            // TODO: correct avobject
            println!("Checking interpreted result {:?} expected {:?}", fmt_interpreted, fmt_expected);
            assert_eq!(i_result, $expected);
            

            // let c_result = eval(read(String::from($e)))[0];
            // println!("Checking compiled result");
            // assert_eq!(c_result, $expected);
        });
    }

    macro_rules! read_eval_check_f {
        ($e:expr, $expected:expr) => ({
            // Execute both a compiled and interpreted version
            let i_result = interpreter::interpret_one(String::from($e));
            let i_result_f = f64::from_bits(i_result);

            println!("Checking interpreted result: {:?} {:?}", i_result_f, $expected);
            assert_eq!(i_result_f, $expected);
            
            // let c_result = eval(read(String::from($e)))[0];
            // let c_result_f = f64::from_bits(c_result);
            // println!("Checking compiled result: {:?} {:?}", c_result, c_result_f);
            // assert_eq!(c_result_f, $expected);
        });
    }

    #[test]
    fn test_reval_num_literals() {
        read_eval_check_f!("9.0", 9.0);
        read_eval_check_f!("42", 42.0);
        read_eval_check_f!("3.14159", 3.14159);
        read_eval_check_f!("10e5", 10e5);
    }

    #[test]
    fn test_reval_arithmetic() {
        read_eval_check_f!("( 2 ) ", 2.0);
        read_eval_check_f!("1 + 2", 3.0);
        read_eval_check_f!("3 * 2", 6.0);
        read_eval_check_f!("12 * 2 / 3", 8.0);
        read_eval_check_f!("48 / 3 / 2", 8.0);
        read_eval_check_f!("1 + 2 * 3 + 4", 11.0);
        read_eval_check_f!("2 * (3 + 4) ", 14.0);
        read_eval_check_f!("2 * 2 / (5 - 1) + 3", 4.0);
    }

    #[test]
    fn test_unary_minus(){
        read_eval_check_f!("2 + -1", 1.0);
        read_eval_check_f!("5 * -2", -10.0);
        read_eval_check_f!("5 * -(2)", -10.0);
        read_eval_check_f!("5 * -(1 + 1)", -10.0);
        read_eval_check_f!("-(4) + 2", -2.0);
    }

    #[test]
    fn test_reval_bool() {
        read_eval_check!("true", SYMBOL_TRUE.symbol);
        read_eval_check!("false", SYMBOL_FALSE.symbol);
        read_eval_check!("true or false", SYMBOL_TRUE.symbol);
        read_eval_check!("true and false", SYMBOL_FALSE.symbol);
    }

    #[test]
    fn test_reval_bool_not() {
        // Not is kind of a special case since it's a bit of a unary op
        read_eval_check!("true and not false", SYMBOL_TRUE.symbol);
        read_eval_check!("not true or false", SYMBOL_FALSE.symbol);
    }

    #[test]
    fn test_reval_comparison() {
        read_eval_check!("1 < 2", SYMBOL_TRUE.symbol);
        read_eval_check!("2 < 1", SYMBOL_FALSE.symbol);
        read_eval_check!("2 > 1", SYMBOL_TRUE.symbol);
        read_eval_check!("1 >= 0", SYMBOL_TRUE.symbol);
        read_eval_check!("-1 > 1", SYMBOL_FALSE.symbol);
    }


    #[test]
    fn test_program_eval() {
        let cell_a = CellRequest {id: 1, name: Some(String::from("one")), input: String::from("1 + 1")};
        let cell_b = CellRequest {id: 2, name: Some(String::from("two")), input: String::from("2 + 1")};

        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: Vec::new(),
            input: None
        };
        program.body.push(cell_a);
        program.body.push(cell_b);

        let i_result = interpreter::interpret_all(program);

        let expected_a = CellResponse {
            id: 1, 
            output: String::from("2"),
            error: String::from("")
        };

        let expected_b = CellResponse {
            id: 2, 
            output: String::from("3"),
            error: String::from("")
        };

        let mut expected_results = Vec::new();
        expected_results.push(expected_a);
        expected_results.push(expected_b);

        assert_eq!(i_result.results, expected_results);
    }


    #[test]
    fn test_identifiers() {
        let cell_a = CellRequest {id: 1, name: Some(String::from("One")), input: String::from("1 + 1")};
        let cell_b = CellRequest {id: 2, name: Some(String::from("two")), input: String::from("One + 3")};

        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: Vec::new(),
            input: None
        };
        program.body.push(cell_a);
        program.body.push(cell_b);

        let i_result = interpreter::interpret_all(program);


        let expected_a = CellResponse {
            id: 1, 
            output: String::from("2"),
            error: String::from("")
        };

        let expected_b = CellResponse {
            id: 2, 
            output: String::from("5"),
            error: String::from("")
        };

        let mut expected_results = Vec::new();
        expected_results.push(expected_a);
        expected_results.push(expected_b);

        assert_eq!(i_result.results, expected_results);    
    }


    #[test]
    fn test_resolution() {
        let cell_a = CellRequest {id: 1, name: Some(String::from("one")), input: String::from("1 + 1")};
        let cell_b = CellRequest {id: 2, name: Some(String::from("two")), input: String::from("one")};
        let cell_c = CellRequest {id: 3, name: Some(String::from("three")), input: String::from("two")};

        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: Vec::new(),
            input: None
        };
        program.body.push(cell_a);
        program.body.push(cell_b);
        program.body.push(cell_c);

        let i_result = interpreter::interpret_all(program);

        let expected_a = CellResponse {
            id: 1, 
            output: String::from("2"),
            error: String::from("")
        };

        let expected_b = CellResponse {
            id: 2, 
            output: String::from("2"),
            error: String::from("")
        };

        let expected_c = CellResponse {
            id: 3, 
            output: String::from("2"),
            error: String::from("")
        };        

        let mut expected_results = Vec::new();
        expected_results.push(expected_a);
        expected_results.push(expected_b);
        expected_results.push(expected_c);

        assert_eq!(i_result.results, expected_results);    
    }    


    #[test]
    fn test_resolution_order() {
        // Should order the cells appropriately since two depends on three
        let cell_a = CellRequest {id: 1, name: Some(String::from("one")), input: String::from("1 + 1")};
        let cell_b = CellRequest {id: 2, name: Some(String::from("two")), input: String::from("three")};
        let cell_c = CellRequest {id: 3, name: Some(String::from("three")), input: String::from("one")};

        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: Vec::new(),
            input: None
        };
        program.body.push(cell_a);
        program.body.push(cell_b);
        program.body.push(cell_c);

        let i_result = interpreter::interpret_all(program);

        let expected_a = CellResponse {
            id: 1, 
            output: String::from("2"),
            error: String::from("")
        };

        let expected_b = CellResponse {
            id: 2, 
            output: String::from("2"),
            error: String::from("")
        };

        let expected_c = CellResponse {
            id: 3, 
            output: String::from("2"),
            error: String::from("")
        };        

        let mut expected_results = Vec::new();
        // Evaluate 3 before 2
        expected_results.push(expected_a);
        expected_results.push(expected_c);
        expected_results.push(expected_b);

        assert_eq!(i_result.results, expected_results);    
    }


    #[test]
    fn test_reval_string_literals() {
        let cell_a = CellRequest {id: 1, name: Some(String::from("one")), input: String::from("\"hello\"")};
        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: vec![cell_a],
            input: None
        };
        let i_result = interpreter::interpret_all(program);
        println!("{:?}", i_result);
        // assert_eq!(true, false);
    }

    #[test]
    fn test_symbol_ref() {
        // Can't just have single value inputs anymore, need cells as inputs
        let program = EvalRequest {
            body: vec![
                CellRequest {id: 1, name: Some(String::from("one")), input: String::from("True")},
                CellRequest {id: 2, name: Some(String::from("two")), input: String::from("one")}
            ],
            input: None
        };
        let i_result = interpreter::interpret_all(program);
        println!("{:?}", i_result);
        let expected_results = vec![
            CellResponse { id: 1, output: String::from("True"), error: String::from("") },
            CellResponse { id: 2, output: String::from("True"), error: String::from("") },
        ];
        assert_eq!(i_result.results, expected_results);
    }


    #[test]
    fn test_builtin_fncall() {
        let program = EvalRequest {
            body: vec![
                CellRequest {id: 1, name: Some(String::from("one")), input: String::from("min(4, 3)")},
                CellRequest {id: 2, name: Some(String::from("two")), input: String::from("min(3, 4)")}
            ],
            input: None
        };
        let i_result = interpreter::interpret_all(program);
        let expected_results = vec![
            CellResponse { id: 1, output: String::from("3"), error: String::from("") },
            CellResponse { id: 2, output: String::from("3"), error: String::from("") },
        ];
        assert_eq!(i_result.results, expected_results);
    }


    #[test]
    fn test_builtin_fn_argeval() {
        let program = EvalRequest {
            body: vec![
                CellRequest {id: 1, name: Some(String::from("one")), input: String::from("min(2 * 2, 2 + 1)")},
                CellRequest {id: 2, name: Some(String::from("two")), input: String::from("min(2, max(1, 4))")}
            ],
            input: None
        };
        let i_result = interpreter::interpret_all(program);
        let expected_results = vec![
            CellResponse { id: 1, output: String::from("3"), error: String::from("") },
            CellResponse { id: 2, output: String::from("2"), error: String::from("") },
        ];
        assert_eq!(i_result.results, expected_results);
    }


    #[test]
    fn test_builtin_math_fn() {
        let program = EvalRequest {
            body: vec![
                CellRequest {id: 1, name: None, input: String::from("abs(-23)")},
                CellRequest {id: 2, name: None, input: String::from("ceil(2.3)")},
                CellRequest {id: 3, name: None, input: String::from("floor(2.3)")},
                CellRequest {id: 4, name: None, input: String::from("round(2.5)")},
                CellRequest {id: 5, name: None, input: String::from("round(-2.5)")},
                CellRequest {id: 6, name: None, input: String::from("truncate(-2.5)")},
                CellRequest {id: 7, name: None, input: String::from("sqrt(25)")},
            ],
            input: None
        };
        let i_result = interpreter::interpret_all(program);
        let expected_results = vec![
            CellResponse { id: 1, output: String::from("23"), error: String::from("") },
            CellResponse { id: 2, output: String::from("3"), error: String::from("") },
            CellResponse { id: 3, output: String::from("2"), error: String::from("") },
            CellResponse { id: 4, output: String::from("3"), error: String::from("") },
            CellResponse { id: 5, output: String::from("-3"), error: String::from("") },
            CellResponse { id: 6, output: String::from("-2"), error: String::from("") },
            CellResponse { id: 7, output: String::from("5"), error: String::from("") },
        ];
        assert_eq!(i_result.results, expected_results);
    }




    #[test]
    fn test_reval_string_concat() {
        let cell_a = CellRequest {id: 1, name: Some(String::from("one")), input: String::from("\"Hello\"")};
        let cell_b = CellRequest {id: 2, name: Some(String::from("two")), input: String::from("one + \" Arevel\"")};
        let cell_c = CellRequest {id: 3, name: Some(String::from("three")), input: String::from("\"Arevel \" + one")};
        // Can't just have single value inputs anymore, need cells as inputs
        let mut program = EvalRequest {
            body: vec![cell_a, cell_b, cell_c],
            input: None
        };
        
        let i_result = interpreter::interpret_all(program);

        let expected_results = vec![
            CellResponse { id: 1, output: String::from("\"Hello\""), error: String::from("") },
            CellResponse { id: 2, output: String::from("\"Hello Arevel\""), error: String::from("") },
            CellResponse { id: 3, output: String::from("\"Arevel Hello\""), error: String::from("") },
        ];

        println!("{:?}", i_result);
        assert_eq!(i_result.results, expected_results);
    }

}
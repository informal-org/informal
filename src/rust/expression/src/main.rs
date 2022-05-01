#![feature(test)]

#[derive(Debug)]
struct Symbol {
    name: String
}

#[derive(Debug)]
struct Parameters {
    params: Vec<Expression>
}

#[derive(Debug, Clone)]
struct Expression {
    declaration: Vec<Value>,
    types: Vec<Value>,
    value: Vec<Value>
}

#[derive(Debug, Clone)]
enum Value {
    Symbol { name: String },
    Parameters { params: Vec<Value> },
    Primitive { value: i64 },
    Expression { expr: Expression }
}


fn main() {
    let add_fn = Expression {
        declaration: vec![
            Value::Symbol{ name: "Add".to_string() }, 
            
        ],
        types: vec![],
        value: vec![]
    };

    println!("Hello, world!");
}


#[cfg(test)]
mod tests {
//     use super::*;
    extern crate test;


    #[test]
    fn test_expression() {
        println!("Testing expression");

    }

}


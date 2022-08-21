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

// Equate = is
// Relate () - f of g
// Predicate : such that.

/*
Equate defines value to variable declarations. Both sides of the type must be structurally equal. 
x = 1 + 1
[x, y] = [0, 100]
*/
fn equate() {
    
}


/*
Relations involving one or more variables, mapping from a domain to a range and connecting data through these links.
color(apple) == red - color of an apple is read.
*/
fn relate() {
    
}

/*
Predicates are used to express something *about* a variable. These can be types, constraints or declarations.
i : Positive Even Number - i is a variable which meets all of these criteria.
Predicates can be defined in terms of other variables (dependent types), parameterized (generics) 
or be based on boolean expressions (predicate types).
x : Arr[x] == 0 - x is a variable such that "arr" at index x is equal to 0.
y : List(Integer) Size(0..N)

A value must structurally conform to the type specified, though it's may contain other fields beyond the Type spec. 
Types defines as functions take in a value and return a boolean value if it matches those constraints.
And finally, types can also be used as simple nominal tags attached onto data, with no structural conformance requirements. 
*/
fn predicate() {

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


use std::collections::HashMap;

// Enum values are associated with their index for fast precedence lookup.
#[derive(Debug,PartialEq)]
pub enum TokenType {
    Keyword(KeywordType),
    Literal(LiteralValue),
    Identifier(u64),
}

#[derive(Debug,PartialEq)]
pub enum LiteralValue {
    NoneValue,
    BooleanValue(u64), 
    NumericValue(f64),    // Integers are represented within the floats.
    StringValue(String),  // TODO: String -> Obj. To c-string.
}

#[derive(Debug,PartialEq,Eq,Copy,Clone)]
#[repr(u8)]
pub enum KeywordType {
    // The u8 repr index into the parser precedence array.
    KwOr = 0,
    KwAnd = 1,
    KwIs = 2,
    KwNot = 3,
    
    KwLt = 4,
    KwLte = 5,
    KwGt = 6,
    KwGte = 7,

    KwPlus = 8,
    KwMinus = 9,
    KwMultiply = 10,
    KwDivide = 11,
    
    KwOpenParen = 12,
    KwCloseParen = 13,
    KwEquals = 14,
}

#[derive(Debug,PartialEq)]
pub enum Value {
    Literal(LiteralValue),
    Identifier(u64)
}

#[derive(Serialize)]
pub struct CellResponse {
    pub id: String,
    pub output: String,
    pub error: String
}

#[derive(Serialize)]
pub struct EvalResponse {
    pub results: Vec<CellResponse>
}

#[derive(Deserialize)]
pub struct CellRequest {
    pub id: String,
    pub input: String,
}

#[derive(Deserialize)]
pub struct EvalRequest {
    pub body: Vec<CellRequest>
}

pub struct AST {
    pub namespace: Namespace,
}

// Kind of a linked list structure
// Pure functions are scoped to their parameters. i.e. null parent.
// You can reference parent, but never child or sibiling data.
pub struct Namespace {
    pub parent: Box<Option<Namespace>>,
    // identifier -> result?
    pub values: HashMap<u64, u64>
}

// #[derive(Debug,PartialEq)]
// pub struct ASTNode {
//     pub node_type: ASTNodeType,
//     pub operator: Option<KeywordType>,
//     pub left: Option<Box<ASTNode>>,
//     pub right: Option<Box<ASTNode>>,
//     pub value: Option<Value>
// }


// #[derive(Debug,PartialEq)]
// pub enum ASTNodeType {
//     BinaryExpression,
//     UnaryExpression,
//     Identifier,
//     Literal
// }


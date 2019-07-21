use std::collections::HashMap;

// Enum values are associated with their index for fast precedence lookup.
#[derive(Debug,PartialEq,Clone)]
pub enum TokenType {
    Keyword(KeywordType),
    Literal(LiteralValue),
    Identifier(u64),
}

#[derive(Debug,PartialEq,Clone)]
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

// #[derive(Debug,PartialEq)]
// pub enum Value {
//     Literal(LiteralValue),
//     Identifier(u64)
// }

#[derive(Serialize, PartialEq, Debug)]
pub struct CellResponse {
    pub id: String,
    pub output: String,
    pub error: String
}

#[derive(Serialize, PartialEq, Debug)]
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
    pub scope: Scope,
    pub body: Vec<ASTNode>
}

impl AST {
    pub fn new() -> AST {
        return AST {
            scope: Scope {
                parent: Box::new(None),
                symbols: HashMap::with_capacity(0),
                next_symbol_id: 1,
                values: Vec::with_capacity(0)
            }, 
            body: Vec::with_capacity(0)
        }
    }
}

#[derive(Debug,PartialEq,Clone)]
pub struct ASTNode {
    pub id: u64,
    pub parsed: Vec<TokenType>,
    pub depends_on: Vec<u64>,
    pub used_by: Vec<u64>,
    // Internal dependency counter used during ordering.
    pub unmet_depend_count: i32,
    pub result: Option<u64>
}

impl ASTNode {
    pub fn new(id: u64) -> ASTNode {
        return ASTNode {
            id: id,
            parsed: Vec::with_capacity(0), 
            depends_on: Vec::with_capacity(0),
            used_by: Vec::with_capacity(0),
            unmet_depend_count: 0,
            result: None
        }
    }

    pub fn err(id: u64, error: u64) -> ASTNode {
        let mut node = ASTNode::new(id);
        node.result = Some(error);
        return node;
    }
}


// Kind of a linked list structure
// Pure functions are scoped to their parameters. i.e. null parent.
// You can reference parent, but never child or sibiling data.
pub struct Scope {
    pub parent: Box<Option<Scope>>,
    
    // Mapping of public IDs to indexes where results will be stored
    pub symbols: HashMap<u64, usize>,
    pub next_symbol_id: usize,

    // symbol index -> result
    pub values: Vec<u64>
}


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


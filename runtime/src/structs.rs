// use avs::structs::AvObject;
use avs::utils::create_value_symbol;
use avs::structs::Atom;
use fnv::FnvHashMap;

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


// Primary AST linked list structure
// Pure functions are scoped to their parameters. i.e. null parent.
// You can reference parent, but never child or sibiling data.
#[derive(Debug)]
pub struct Context {
    pub parent: Box<Option<Context>>,
    
    // Normalized upper case name -> Symbol ID for things defined in this scope
    pub normname_symbols: FnvHashMap<String, u64>,

    // Preserve the original case of the name for printing back to user
    pub symbols_name: FnvHashMap<u64, String>,

    // Cell IDs -> Symbol IDs for cells without a name
    // Only defined for the root Context
    pub cell_symbols: Option<FnvHashMap<u64, u64>>,

    // Mapping of symbol IDs to values indexes for lookup.
    // This could instead be a hash function which does a lookup
    // with linear probing/a perfect hash.
    // pub symbol_index: FnvHashMap<u64, usize>,

    // Stores the running state. Symbol index -> result
    // pub env: AvObject,

    // Symbols -> Index of where the result will be stored
    pub symbols_index: FnvHashMap<u64, usize>,
    
//    pub values: Vec<u64>,

    pub body: Vec<Expression>,

    pub next_symbol_id: u64,

//    pub cell_results: Vec<u64>
}

// AstNode -> Expression
// Context (Scope / Global AST)
impl Context {
    pub fn new(next_symbol_id: u64) -> Context {
        return Context {
            parent: Box::new(None),
            normname_symbols: FnvHashMap::default(),
            symbols_name: FnvHashMap::default(),
            cell_symbols: None,
            symbols_index: FnvHashMap::default(),
            body: Vec::with_capacity(0),
            next_symbol_id: next_symbol_id
        }
    }
    
    // TODO: Methods for defining a child scope

    pub fn get_or_create_cell_symbol(&mut self, cell_id: u64) -> u64 {
        if let Some(existing_id) = self.cell_symbols.as_ref().unwrap().get(&cell_id) {
            *existing_id 
        } else {
            let cell_symbol_value: u64 = create_value_symbol( self.next_symbol_id );
            self.cell_symbols.as_mut().unwrap().insert(cell_id, cell_symbol_value);
            self.next_symbol_id += 1;
            cell_symbol_value
        }

    }
}


#[derive(Debug,PartialEq)]
pub struct Expression {
    pub id: u64,
    pub parsed: Vec<Atom>,
    pub depends_on: Vec<u64>,
    pub used_by: Vec<u64>,
    // Internal dependency counter used during ordering.
    pub unmet_depend_count: i32,
    pub result: Option<u64>
}

impl Expression {
    pub fn new(id: u64) -> Expression {
        return Expression {
            id: id,
            parsed: Vec::with_capacity(0), 
            depends_on: Vec::with_capacity(0),
            used_by: Vec::with_capacity(0),
            unmet_depend_count: 0,
            result: None
        }
    }

    pub fn err(id: u64, error: u64) -> Expression {
        let mut node = Expression::new(id);
        node.result = Some(error);
        return node;
    }

    pub fn set_result(&mut self, result: u64) {
        // Set result only if it wasn't previously set to avoid cloberring errors.
        if self.result.is_none() {
            self.result = Some(result);
        }
    }
}


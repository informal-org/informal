use crate::utils::create_pointer_symbol;
use crate::structs::{Identifier, Atom};
use crate::expression::Expression;
use core::fmt;
use fnv::FnvHashMap;


// Context (Scope / Global AST)
// Primary AST linked list structure
// Pure functions are scoped to their parameters. i.e. null parent.
// You can reference parent, but never child or sibiling data.
pub struct Environment {
    parent: Box<Option<Environment>>,
    
    // Normalized upper case name -> Symbol ID for things defined in this scope
    normname_symbols: FnvHashMap<String, u64>,

    // Symbol ID -> metadata and values
    identifiers: FnvHashMap<u64, Identifier>,

    // TODO: Convert this to an ordermap
    // Raw code
    pub body: Vec<Expression>,

    // TODO: Allocation when there's multiple sub-environments.
    pub next_symbol_id: u64,
}

impl Environment {
    // TODO: Variant for creating a child environment with a parent arg
    pub fn new(next_symbol_id: u64) -> Environment {
        return Environment {
            parent: Box::new(None),
            normname_symbols: FnvHashMap::default(),
            identifiers: FnvHashMap::default(),
            body: Vec::with_capacity(0),
            next_symbol_id: next_symbol_id,
        }
    }

    pub fn define_keyword(&mut self) -> u64 {
        return 0
    }

    pub fn define_identifier(&mut self) -> u64 {
        let next_symbol: u64 = create_pointer_symbol(self.next_symbol_id);
        self.next_symbol_id += 1;
        return next_symbol;
    }

    // Bind a name to an identifier within this scope.
    pub fn bind_name(&mut self, symbol: u64, name: String) {
        // TODO: Handling existing names
        let uname = name.to_uppercase();
        // TODO: name validation (without duplicating)

        if !self.normname_symbols.contains_key(&uname) {
            self.normname_symbols.insert(uname, symbol);
        }
    }

    // Bind an identifier to a value
    pub fn bind_value(&mut self, symbol: u64, value: Atom) {
        
    }

    // Check whether a name has already been used within this scope
    // Note that it doesn't check whether it's used outside of it.
    pub fn is_valid_name(&self, name: String) -> bool {
        // TODO: Other naming criteria check
        let uname = name.to_uppercase();
        return self.normname_symbols.contains_key(&uname) == false;
    }

    pub fn lookup_name(&self, name: String) -> Option<&u64> {
        // get_name_symbol
        let norm_name = name.trim().to_uppercase();
        return self.normname_symbols.get(&norm_name);
    }

    pub fn lookup(&self, symbol: u64) -> Option<&Identifier> {
        return None
    }

    // Resolve a symbol to a terminal value by following pointers
    // Terminates at a max depth
    pub fn deep_resolve(&self, symbol: u64) -> Option<&Identifier> {
        return None;
    }



    

    // pub fn get_name_symbol(&self, name: String) -> Option<&u64> {
    //     
    //     
    // }    

    // pub fn get_symbol_repr(&self, symbol: u64) -> Option<&String> {
    //     return self.symbols_name.get(&symbol);
    // }

    // pub fn next_value_symbol(&mut self) -> u64 {
    //     // These symbols reference themselves
    //     let next_symbol: u64 = create_value_symbol( self.next_symbol_id );
    //     self.next_symbol_id += 1;
    //     return next_symbol;
    // }
    
    // pub fn next_pointer(&mut self) -> u64 {
    // }

    // pub fn get_or_create_cell_symbol(&mut self, cell_id: u64) -> u64 {
    //     if let Some(existing_id) = self.cell_symbols.as_ref().unwrap().get(&cell_id) {
    //         *existing_id 
    //     } else {
    //         let symbol_id = self.next_pointer();
    //         self.cell_symbols.as_mut().unwrap().insert(cell_id, symbol_id);
    //         self.symbols_cell.as_mut().unwrap().insert(symbol_id, cell_id);
    //         symbol_id
    //     }
    // }

    // pub fn get_symbol(&self, name: String) -> Option<u64> {
    //     let name_upper = name.to_uppercase();
    //     let existing_val = self.normname_symbols.get(&name_upper);
    //     if existing_val.is_some() {
    //         return Some(*existing_val.unwrap());
    //     }
    //     return None;
    // }

    // // Symbol used in expression
    // pub fn get_or_create_symbol(&mut self, name: String) -> u64 {
    //     let name_upper = name.to_uppercase();
    //     let existing_val = self.normname_symbols.get(&name_upper);
    //     if existing_val.is_some() {
    //         return *existing_val.unwrap();
    //     }

    //     let symbol_id = self.next_value_symbol();
    //     self.normname_symbols.insert(name_upper, symbol_id);
    //     self.symbols_name.insert(symbol_id, name);
    //     symbol_id
    // }

    // // Symbol used as cell names
    // pub fn define_cell_name(&mut self, trimmed_name: String, symbol: u64) -> Result<u64> {
    //     // TODO: Check name validity - no delimiter characters, doesn't start with :
    //     let name_upper = trimmed_name.to_uppercase();
    //     let existing_val = self.normname_symbols.get(&name_upper);
    //     if existing_val.is_some() {
    //         return Err(PARSE_ERR_USED_NAME);
    //     }
        
    //     self.normname_symbols.insert(name_upper, symbol);
    //     self.symbols_name.insert(symbol, trimmed_name);
    //     return Ok(symbol);
    // }

    // Method for defining external input variables.
    // pub fn define_input(&mut self, trimmed_name: String) -> Result<u64> {
    //     let name_upper = trimmed_name.to_uppercase();
    //     let existing_val = self.normname_symbols.get(&name_upper);
    //     if existing_val.is_some() {
    //         return Err(PARSE_ERR_USED_NAME);
    //     }
    //     let symbol = self.next_pointer();
        
    //     self.normname_symbols.insert(name_upper, symbol);
    //     self.symbols_name.insert(symbol, trimmed_name);
    //     return Ok(symbol);
    // }

}


#[cfg(not(target_os = "unknown"))]
impl fmt::Debug for Environment {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut parts = vec![];
        parts.push(String::from("Context {\n"));

        parts.push(format!("Cells: {:#?}\n", self.identifiers));
        parts.push(format!("Names: {:#?}\n", self.normname_symbols));
        parts.push(format!("Body: {:#?}\n", self.body));

        parts.push(String::from("\n}"));

        write!(f, "{}", parts.join(""))
    }
}



use crate::types::is_symbol;
use crate::utils::create_pointer_symbol;
use crate::structs::{Identifier, Atom};
use crate::expression::Expression;
use crate::types::{is_pointer, is_nan};
use crate::constants::*;
use crate::macros::*;

use core::fmt;
use fnv::FnvHashMap;
use std::rc::Rc;
use std::cell::RefCell;



// Context (Scope / Global AST)
// Primary AST linked list structure
// Pure functions are scoped to their parameters. i.e. null parent.
// You can reference parent, but never child or sibiling data.
pub struct Environment {
    parent: Box<Option<Environment>>,
    
    // Normalized upper case name -> Symbol ID for things defined in this scope
    // names
    normname_symbols: FnvHashMap<String, u64>,

    // Symbol ID -> metadata and values
    // values
    identifiers: FnvHashMap<u64, Identifier>,

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

        if let Some(existing) = self.identifiers.get_mut(&symbol) {
            existing.name = Some(name);
        } else {
            let variable = Identifier {
                symbol: symbol,
                name: Some(name),
                value: None
            };
            self.identifiers.insert(symbol, variable);
        }
    }

    // Bind an identifier to a value
    pub fn bind_value(&mut self, symbol: u64, value: Atom) {
        // self.identifiers.insert(symbol, value)
        if let Some(existing) = self.identifiers.get_mut(&symbol) {
            existing.value = Some(value);
        } else {
            let variable = Identifier {
                symbol: symbol,
                name: None,
                value: Some(value)
            };
            self.identifiers.insert(symbol, variable);
        }
    }

    // A lower-level form of bind_value to save the stack result
    pub fn bind_result(&mut self, symbol: u64, result: u64) {
        let atom = resolve_atom!(&self, result);
        self.bind_value(symbol, atom);
    }

    pub fn init_value(&mut self, value: Atom) -> u64 {
        let symbol_id = self.define_identifier();
        self.bind_value(symbol_id, value);
        return symbol_id;
    }

    // Check whether a name has already been used within this scope
    // Note that it doesn't check whether it's used outside of it.
    pub fn is_valid_name(&self, name: String) -> bool {
        // TODO: Other naming criteria check
        let uname = name.to_uppercase();
        return self.normname_symbols.contains_key(&uname) == false;
    }

    pub fn lookup_by_name(&self, name: String) -> Option<&u64> {
        // get_name_symbol
        let norm_name = name.trim().to_uppercase();
        return self.normname_symbols.get(&norm_name);
    }

    pub fn lookup(&self, symbol: u64) -> Option<&Identifier> {
        return self.identifiers.get(&symbol)
    }

    // Resolve a symbol to a terminal value by following pointers
    // Terminates at a max depth
    pub fn deep_resolve(&self, symbol: u64) -> Option<&Identifier> {
        let mut count = 0;
        let mut current_symbol = symbol;

        while count < 1000 {
            if let Some(ident) = self.lookup(current_symbol) {
                
                if let Some(value) = &ident.value {
                    if let Atom::SymbolValue(next_symbol) = value {
                        // Not a pointer, so terminal value
                        if is_symbol(*next_symbol) {
                            return Some(ident)
                        }

                        // Check for circular pointers
                        if *next_symbol == current_symbol || *next_symbol == symbol {
                            println!("Cyclic symbol reference");
                            return None
                        }
                        current_symbol = *next_symbol
                    }
                    else {
                        return Some(ident)
                    }
                } else {
                    return None
                }
            }

            count += 1;
        }
        return None
    }
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



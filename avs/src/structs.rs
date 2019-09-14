use crate::types::is_symbol;
use crate::types::__av_typeof;
use alloc::rc::Rc;
use alloc::string::String;
use alloc::vec::Vec;
use crate::constants::*;
use crate::functions::*;
use crate::utils::{create_string_pointer, create_pointer_symbol, truncate_symbol};
use fnv::FnvHashMap;

use crate::format::*;


#[derive(Debug,PartialEq)]
pub enum ValueType {
    NumericType,
    StringType,
	ObjectType,
    SymbolType,
    HashMapType
}

#[derive(PartialEq,Clone)]
pub enum Atom {
    NumericValue(f64),
    StringValue(String),
    SymbolValue(u64),
    ObjectValue(AvObject),
    HashMapValue(FnvHashMap<u64, Atom>),
    FunctionValue(NativeFn)
}


// Context available during program execution managing current runtime state
#[derive(PartialEq,Clone)]
pub struct Runtime {
    pub symbols: FnvHashMap<u64, Atom>,
    pub next_symbol_id: u64
}

// Tuple of symbol -> value for storage
pub struct SymbolAtom {
    pub symbol: u64, 
    pub atom: Atom
}

pub struct Keyword {
    pub symbol: u64, 
    pub name: &'static str,
    pub precedence: Option<u8>,
    pub operation: Option<extern "C" fn(&mut Runtime, u64, u64) -> u64>
}

impl PartialEq for Keyword {
    fn eq(&self, other: &Self) -> bool {
        self.symbol == other.symbol
    }
}

pub struct Module {
    pub symbol: u64,
    pub name: &'static str,
    pub value: Atom         // Generally to the function
}

impl PartialEq for Module {
    fn eq(&self, other: &Self) -> bool {
        self.symbol == other.symbol
    }
}



impl Runtime {
    pub fn new(next_symbol_id: u64) -> Runtime {
        let mut runtime = Runtime {
            symbols: FnvHashMap::with_capacity_and_hasher(25, Default::default()),
            next_symbol_id: next_symbol_id
        };
        
        return runtime
    }

    // TODO: Load module for imports

    /// Saves an object into the symbol table and returns the symbol
    pub fn save_atom(&mut self, atom: Atom) -> u64 {
        let next_id = create_pointer_symbol(self.next_symbol_id);
        self.symbols.insert(next_id, atom);
        self.next_symbol_id += 1;
        return next_id
    }

    pub fn save_string(&mut self, atom: Atom) -> u64 {
        let next_id = create_string_pointer(self.next_symbol_id);
        self.symbols.insert(next_id, atom);
        self.next_symbol_id += 1;
        return next_id
    }    

    /// Replace the value of an existing symbol in the symbol table
    pub fn set_atom(&mut self, symbol: u64, atom: Atom) {
        self.symbols.insert(symbol, atom);
    }

    /// Set a symbol value, with automatic casting of value
    pub fn set_value(&mut self, symbol: u64, value: u64) {
        let atom: Atom = match __av_typeof(value){
            ValueType::NumericType => {
                Atom::NumericValue(f64::from_bits(value))
            },
            ValueType::SymbolType => {
                if let Some(resolved) = self.resolve_symbol(value) {
                    println!("Setting {:X} to {:X} -> {:?}", symbol, value, resolved);
                    // Partial implementation of a copy
                    match resolved {
                        Atom::NumericValue(val) => Atom::NumericValue(*val),
                        Atom::StringValue(val) => Atom::StringValue(val.to_string()),
                        _ => Atom::SymbolValue(value)
                    }
                } else {
                    // May just be a built-in symbol? 
                    println!("Could not resolve symbol {:X}", value);
                    Atom::SymbolValue(value)
                }
            },
            _ => {
                Atom::SymbolValue(value)
            }
        };
        self.set_atom(symbol, atom);
    }
    
    pub fn get_atom(&self, symbol: u64) -> Option<&Atom> {
        // TODO: Not found
        // return Rc::clone(&obj_arr.get())
        return self.symbols.get(&symbol);
    }

    /// Resolve a symbol to their final destination, following links up to a max depth
    pub fn resolve_symbol(&self, symbol: u64) -> Option<&Atom> {
        let mut count = 0;
        let mut current_symbol = symbol;
        // println!("{}", fmt_symbols_map(&self.symbols));
        
        while count < 1000 {
            if let Some(atom) = self.symbols.get(&current_symbol) {
                match atom {
                    Atom::SymbolValue(next_symbol) => {
                        // Terminal symbol
                        if is_symbol(*next_symbol) {
                            return Some(atom)
                        }

                        // Check for circular pointers
                        if *next_symbol == current_symbol || *next_symbol == symbol {
                            println!("Cyclic symbol reference");
                            // Terminate on cycles
                            return None
                        }
                        current_symbol = *next_symbol
                    }, 
                    _ => return Some(atom)
                }
            } else {
                println!("symbol not found");
                return None
            }
            count += 1;
        }
        println!("Max depth exceeded");
        // Max search depth, terminate
        return None
    }

    pub fn get_string(&self, symbol: u64) -> Option<&String> {
        // TODO: Not found
        // return Rc::clone(&obj_arr.get())
        let atom = self.get_atom(symbol);
        if let Some(atom_val) = atom {
            match atom_val {
                Atom::StringValue(str_val) => return Some(str_val),
                _ => return None
            }
        }
        return None;
    }


    pub fn get_number(&self, symbol: u64) -> Option<&f64> {
        // TODO: Not found
        // return Rc::clone(&obj_arr.get())
        let atom = self.get_atom(symbol);
        if let Some(atom_val) = atom {
            match atom_val {
                Atom::NumericValue(num_val) => return Some(num_val),
                _ => return None
            }
        }
        return None;
    }

}



#[derive(Debug,PartialEq,Clone)]
pub struct AvObject {
    // Class and ID are truncated symbol IDs. // TODO: Re-enable truncation
    pub id: u64,        // Used for hash1ed field access.
    pub av_class: u64,

    // Values are required for objects. Objects are optional. (unallocated for strings)
    // This can be used as a list or a hash table for field access.
    pub av_values: Option<Vec<u64>>,
}


impl AvObject {
    pub fn new_env() -> AvObject {
        let mut results: Vec<u64> = Vec::new();
        let mut obj_vec: Vec<Rc<AvObject>> = Vec::new();

        return AvObject {
            id: 0,          // TODO
            av_class: AV_CLASS_ENVIRONMENT,
            av_values: Some(results),
        };
    }

    pub fn new() -> AvObject {
        // TODO: Should take in class and id 
        // Allocate an empty object
        return AvObject {
            id: 0,
            av_class: 0, // TODO
            av_values: None,
        };
    }

    pub fn resize_values(&mut self, new_len: usize) {
        // Since results are often saved out of order, pre-reserve space
        if self.av_values.is_some() {
            self.av_values.as_mut().unwrap().resize(new_len, 0);
        }
    }

    pub fn save_value(&mut self, index: usize, value: u64) {
        if self.av_values.is_some() {
            // TODO: Resize?
            self.av_values.as_mut().unwrap()[index] = value;
        }
    }

    pub fn get_value(&mut self, index: usize) -> u64 {
        return self.av_values.as_ref().unwrap()[index];
    }

}

#[cfg(test)]
mod tests {
    use super::*;
    extern crate test;

    use test::Bencher;
    pub const BENCH_SIZE: u64 = 10_000;

    #[test]
    fn test_symbol_type() {
        let mut env = Runtime::new(APP_SYMBOL_START);
        // TODO: Test longer vs shorter string
        let symbol_id = env.save_string(Atom::StringValue("Hello".to_string()));
        let symbol_header = symbol_id & VALHEAD_MASK;
        assert_eq!(symbol_header, VALUE_T_PTR_STR);
    }
}
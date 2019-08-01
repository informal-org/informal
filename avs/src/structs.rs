use crate::types::__av_typeof;
use core::cell::RefCell;
use alloc::rc::Rc;
use alloc::string::String;
use alloc::vec::Vec;
use crate::utils::{truncate_symbol};
use crate::constants::*;
use fnv::FnvHashMap;


#[derive(Debug,PartialEq)]
pub enum ValueType {
    NumericType,
    StringType,
	ObjectType,
    SymbolType
}

#[derive(PartialEq)]
pub enum Atom {
    NumericValue(f64),
    StringValue(String),
    SymbolValue(u64),
    ObjectValue(AvObject)
}

// Context available during program execution managing current runtime state
pub struct Runtime {
    pub symbols: FnvHashMap<u64, Atom>,
    pub next_symbol_id: u64
}

impl Runtime {
    pub fn new(next_symbol_id: u64) -> Runtime {
        Runtime {
            symbols: FnvHashMap::default(), 
            next_symbol_id: next_symbol_id
        }
    }

    /// Saves an object into the symbol table and returns the symbol
    pub fn save_atom(&mut self, atom: Atom) -> u64 {
        let next_id = self.next_symbol_id;
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
                if let Some(resolved) = self.resolve_symbol(symbol) {
                    // Partial implementation of a copy
                    match resolved {
                        Atom::NumericValue(val) => Atom::NumericValue(*val),
                        Atom::StringValue(val) => Atom::StringValue(val.to_string()),
                        _ => Atom::SymbolValue(symbol)
                    }
                } else {
                    println!("Could not resolve symbol");
                    Atom::SymbolValue(symbol)
                }
            },
            _ => {
                Atom::SymbolValue(symbol)
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
        while count < 100 {
            if let Some(atom) = self.symbols.get(&current_symbol) {
                match atom {
                    Atom::SymbolValue(next_symbol) => {
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


    // pub fn get_string(&self, symbol: u64) -> Option<String> {
    //     let atom = self.get_atom(symbol);
    //     if let Some(atom_val) = atom {
    //         match {

    //         }
    //     }
    //     return None
    // }
}



#[derive(Debug,PartialEq)]
pub struct AvObject {
    // Class and ID are truncated symbol IDs. // TODO: Re-enable truncation
    pub id: u64,        // Used for hash1ed field access.
    pub av_class: u64,

    // Values are required for objects. Objects are optional. (unallocated for strings)
    // This can be used as a list or a hash table for field access.
    pub av_values: RefCell<Option<Vec<u64>>>,
//    pub av_objects: RefCell<Option<Vec<Rc<AvObject>>>>,
    // Future: Can be used for byte storage as well (via unsafe to accomodate invalid utf-8 bytes)
//    pub av_string: Option<String>
}


impl AvObject {
    pub fn new_env() -> AvObject {
        let mut results: Vec<u64> = Vec::new();
        let mut obj_vec: Vec<Rc<AvObject>> = Vec::new();

        return AvObject {
            id: 0,          // TODO
            av_class: AV_CLASS_ENVIRONMENT,
            av_values: RefCell::new(Some(results)),
//            av_objects: RefCell::new(Some(obj_vec)),
//            av_string: None
        };
    }

    pub fn new_string(value: String) -> AvObject {
        return AvObject {
            id: 0,
            av_class: AV_CLASS_STRING,
            av_values: RefCell::new(None),
//            av_objects: RefCell::new(None),
//            av_string: Some(value)
        };
    }

    pub fn new() -> AvObject {
        // TODO: Should take in class and id 
        // Allocate an empty object
        return AvObject {
            id: 0,
            av_class: 0, // TODO
            av_values: RefCell::new(None),
//            av_objects: RefCell::new(None),
//            av_string: None,
        };
    }

    pub fn resize_values(&mut self, new_len: usize) {
        // Since results are often saved out of order, pre-reserve space
        let mut values = self.av_values.borrow_mut();
        if values.is_some() {
            values.as_mut().unwrap().resize(new_len, 0);
        }
    }

    pub fn save_value(&mut self, index: usize, value: u64) {
        let mut values = self.av_values.borrow_mut();
        if values.is_some() {
            // TODO: Resize?
            values.as_mut().unwrap()[index] = value;
        }
    }

    pub fn get_value(&mut self, index: usize) -> u64 {
        let values = self.av_values.borrow();
        return values.as_ref().unwrap()[index];
    }

}




// // TODO: AvBytes
// #[derive(Debug,PartialEq)]
// pub struct AvObjectString {
//     pub object: AvObjectBasic,
//     pub av_string: str   // ToDo String vs str
// }

// // Equivalent to an object, just separate for methods.
// #[derive(Debug,PartialEq)]
// pub struct AvObjectArray {
//     pub object: AvObject,
// }


// Matches with the IO object format. The fields present vary based on object type.
// #[derive(Debug,PartialEq)]
// pub struct AvObject {
//     pub avtype: AvObjectType,
//     pub avclass: u32,
//     pub avhash: u64,
//     pub length: u32,
//     pub values: RefCell<Option<Vec<u64>>>,
//     pub av_string: Option<String>,     // TOXO: &str vs str vs String
//     pub avbytes: RefCell<Option<Vec<u8>>>,
//     // Immutable list of reference counted interior mutable cells
//     // RC was required for get_object.
//     pub av_objects: RefCell<Option<Vec<Rc<AvObject>>>>
// }

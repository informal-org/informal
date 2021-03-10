use crate::environment::Environment;
use crate::functions::NativeFn;
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

#[derive(Debug)]
pub struct Identifier {
    pub symbol: u64,
    pub name: Option<String>,
    pub value: Option<Atom>
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
    pub operation: Option<extern "C" fn(&mut Environment, u64, u64) -> u64>
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
    use crate::constants::*;
    extern crate test;

    use test::Bencher;
    pub const BENCH_SIZE: u64 = 10_000;

    #[test]
    fn test_symbol_type() {
        let mut env = Environment::new(APP_SYMBOL_START);
        // TODO: Test longer vs shorter string
        let symbol_id = env.init_value(Atom::StringValue("Hello".to_string()));
        let symbol_header = symbol_id & VALHEAD_MASK;
        // assert_eq!(symbol_header, VALUE_T_PTR_STR);
        assert_eq!(symbol_header, VALUE_T_PTR_OBJ);
    }
}
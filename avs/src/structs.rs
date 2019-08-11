use crate::types::__av_typeof;
use alloc::rc::Rc;
use alloc::string::String;
use alloc::vec::Vec;
use crate::constants::*;
use crate::utils::{create_string_pointer, create_pointer_symbol, truncate_symbol};
use fnv::FnvHashMap;
use std::time::{SystemTime, UNIX_EPOCH};


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
    HashMapValue(FnvHashMap<u64, Atom>)
}

// Context available during program execution managing current runtime state
pub struct Runtime {
    pub symbols: FnvHashMap<u64, Atom>,
    pub next_symbol_id: u64
}

// Tuple of symbol -> value for storage
pub struct SymbolAtom {
    pub symbol: u64, 
    pub atom: Atom
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
                if let Some(resolved) = self.resolve_symbol(symbol) {
                    // Partial implementation of a copy
                    match resolved {
                        Atom::NumericValue(val) => Atom::NumericValue(*val),
                        Atom::StringValue(val) => Atom::StringValue(val.to_string()),
                        _ => Atom::SymbolValue(symbol)
                    }
                } else {
                    // May just be a built-in symbol? 
                    println!("Could not resolve symbol {:X}", symbol);
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
        while count < 1000 {
            if let Some(atom) = self.symbols.get(&current_symbol) {
                match atom {
                    Atom::SymbolValue(next_symbol) => {
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


    #[test]
    fn test_symbol_type() {
        let mut env = Runtime::new(APP_SYMBOL_START);
        // TODO: Test longer vs shorter string
        let symbol_id = env.save_string(Atom::StringValue("Hello".to_string()));
        let symbol_header = symbol_id & VALHEAD_MASK;
        assert_eq!(symbol_header, VALUE_T_PTR_STR);
    }

    #[bench]
    fn bench_direct(b: &mut Bencher) {
        let mut next_symbol = APP_SYMBOL_START;
        let mut runtime: Vec<SymbolAtom> = Vec::new();

        for i in 0..1000 {
            // runtime.save_atom(Atom::NumericValue(999.0));
            let value = SymbolAtom {
                symbol: create_pointer_symbol(APP_SYMBOL_START + i),
                atom: Atom::NumericValue(999.0)
            };
            runtime.push(value);
        }
        b.iter(|| {
            let symbol = create_pointer_symbol(APP_SYMBOL_START);
            for i in 0..1000 {
                let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + i);

                let index = (truncate_symbol(lookup_symbol) - truncate_symbol(symbol)) as usize;

                let value = &runtime[index];
                if value.symbol == lookup_symbol {
                    value.symbol;
                }
            }
        });
    }

    // #[bench]
    // fn bench_linear(b: &mut Bencher) {
    //     let mut next_symbol = APP_SYMBOL_START;
    //     let mut runtime: Vec<SymbolAtom> = Vec::new();

    //     for i in 0..10_000 {
    //         // runtime.save_atom(Atom::NumericValue(999.0));
    //         let value = SymbolAtom {
    //             symbol: create_pointer_symbol(APP_SYMBOL_START + i),
    //             atom: Atom::NumericValue(999.0)
    //         };
    //         runtime.push(value);
    //     }
    //     b.iter(|| {
    //         for i in 0..10_000 {
    //             let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + i);

    //             for index in 0..10_000 {
    //                 let value = &runtime[index];
    //                 if value.symbol == i {
    //                     value.symbol;
    //                     break;
    //                 }
    //             }
    //         }
    //     });
    // }


    #[bench]
    fn bench_binary(b: &mut Bencher) {
        let mut next_symbol = APP_SYMBOL_START;
        let mut runtime: Vec<SymbolAtom> = Vec::new();

        for _ in 0..1000 {
            // runtime.save_atom(Atom::NumericValue(999.0));
            let value = SymbolAtom {
                symbol: create_pointer_symbol(next_symbol),
                atom: Atom::NumericValue(999.0)
            };
            runtime.push(value);
            next_symbol = next_symbol + 1 + ((pseudo_random() % 1000) as u64);
        }
        b.iter(|| {
            for i in 0..1000 {
                let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + i);

                let mut min_index: usize = 0;
                let mut max_index = runtime.len();

                while min_index < max_index {
                    let mid = ((min_index + max_index) / 2) as usize;
                    let mid_symbol = runtime[mid].symbol;
                    if mid_symbol == lookup_symbol {
                        break;
                    } else if mid_symbol < lookup_symbol {
                        min_index = (mid + 1) as usize;
                    } else {
                        max_index = (mid - 1) as usize;
                    }
                }
            }
        });
    }

    fn pseudo_random() -> u32 {
        // Between 0 and 1 billion
        let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .subsec_nanos();
        return nanos;
    }


    #[bench]
    fn bench_weighted_binary(b: &mut Bencher) {
        let mut next_symbol = APP_SYMBOL_START;
        let mut runtime: Vec<SymbolAtom> = Vec::new();

        for _ in 0..1000 {
            // runtime.save_atom(Atom::NumericValue(999.0));
            let value = SymbolAtom {
                symbol: create_pointer_symbol(next_symbol),
                atom: Atom::NumericValue(999.0)
            };
            runtime.push(value);
            next_symbol = next_symbol + 1 + ((pseudo_random() % 1000) as u64);
            // next_symbol = next_symbol + 1;
        }
        b.iter(|| {
            for i in 0..1000 {
                let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + i);

                let trunc_look = truncate_symbol(lookup_symbol);

                let mut min_index: usize = 0;
                let mut max_index = runtime.len();

                let mut min_symbol = truncate_symbol(runtime[min_index].symbol);
                let mut max_symbol = truncate_symbol(runtime[max_index - 1].symbol);
                let mut ends_diff = (max_symbol - min_symbol) as f64;

                let mut min_diff = (trunc_look - min_symbol) as f64;
                let mut max_diff = (max_symbol - trunc_look) as f64;

                // let mut mid = ((min_index + min_diff) / 2) as usize;
                // let mut mid = (min_index + min_diff) as usize;
                // let biased_mid = (min_index + min_diff) as usize;
                
                // let mut mid = (min_diff + (max_index - max_diff) ) / 2;
                // let mid_pt = ((min_diff ) + ( max_diff / ends_diff )) / 2.0;

                let mut mid_pt = ( (min_diff / ends_diff )) *  ((max_index - 1) as f64);
                let mut mid = mid_pt as usize;

                // let mut mid = mid_pt as usize;

                // println!("min {} max {} ends {} => {} : {}", min_diff, max_diff, ends_diff, mid_pt, mid);
                // if i > 100 {
                //     panic!();
                // }
                

                // If target was min symbol, it should say min = 0, max = max value and you should search at 0. 
                // if target was max symbol, it should say min = max, max = 0, and you should search there. 

                
                // if mid > true_mid {
                //     mid = true_mid;
                // }
                


                while min_index < max_index {
                    let mid_symbol = runtime[mid].symbol;
                    if mid_symbol == lookup_symbol {
                        break;
                    } else if mid_symbol < lookup_symbol {
                        min_index = (mid + 1) as usize;
                        min_symbol = truncate_symbol(mid_symbol);
                    } else {
                        max_index = (mid - 1) as usize;
                        max_symbol = truncate_symbol(mid_symbol);
                    }

                    ends_diff = (max_symbol - min_symbol) as f64;
                    min_diff = (trunc_look - min_symbol) as f64;

                    mid_pt = ( (min_diff / ends_diff )) * ((max_index - 1) as f64);
                    mid = min_index + 1 + (mid_pt as usize);
                    // if mid <= max_index {
                    //     mid += 1;
                    // }


                    // mid = ((min_index + max_index) / 2) as usize;

                    // let min_diff = (trunc_look - min_symbol) as usize;
                    // let max_diff = (max_symbol - trunc_look) as usize;

                    // mid = (min_diff + (max_index - max_diff) ) / 2;

                }
            }
        });
    }    


    #[bench]
    fn bench_hash(b: &mut Bencher) {
        let mut runtime = Runtime::new(APP_SYMBOL_START);
        for i in 0..1000 {
            runtime.save_atom(Atom::NumericValue(999.0));
        }
        b.iter(|| {
            for i in 0..1000 {
                runtime.get_atom(create_pointer_symbol(APP_SYMBOL_START + i));
            }
        });
    }

    // #[bench]
    // fn bench_binary(b: &mut Bencher) {
    //     b.iter(|| add_two(2));
    // }
}




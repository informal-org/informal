use crate::structs::Atom;
use core::fmt;
use fnv::FnvHashMap;


#[cfg(not(target_os = "unknown"))]
use crate::runtime::ID_SYMBOL_MAP;

#[cfg(not(target_os = "unknown"))]
pub fn repr_symbol(symbol: &u64) -> String {
    let builtin_name = ID_SYMBOL_MAP.get(symbol);
    if builtin_name.is_some(){
        format!("{}", builtin_name.unwrap())
    } else {
        format!("{:X}", symbol)
    }
}

#[cfg(not(target_os = "unknown"))]
pub fn repr_number(number: u64) -> String {
    let f_val: f64 = f64::from_bits(number);
    return repr_float(f_val);
}

#[cfg(not(target_os = "unknown"))]
pub fn repr_float(f_val: f64) -> String {
    // Print integers without the trailing zeroes
    if f_val.fract() == 0.0 {
        return format!("{:?}", f_val.trunc() as i64)
    } else {
        return format!("{:?}", f_val)
    }
}

#[cfg(not(target_os = "unknown"))]
pub fn repr_atom(atom: &Atom) -> String {
    match atom {
        Atom::NumericValue(num) => {
            format!("{}", repr_float(*num))
        },
        Atom::StringValue(str_val) => {
            format!("\"{}\"", str_val)
        }
        Atom::SymbolValue(symbol) => {
            repr_symbol(symbol)
        },
        Atom::ObjectValue(obj_val) => {
            format!("{}", obj_val.id)
        },
        Atom::HashMapValue(map_val) => {
            format!("{:#?}", map_val)
        },
        Atom::FunctionValue(fn_val) => {
            format!("<Function>")
        }
    }
}

#[cfg(not(target_os = "unknown"))]
pub fn fmt_symbols_map(map: &FnvHashMap<u64, Atom>) -> String {
    let mut output = vec![];
    output.push(String::from("{"));
    for (key, val) in map.iter() {
        output.push(format!("\t{:X}: {:?}", key, val));
    }
    output.push(String::from("}"));
    return output.join("\n");
}

#[cfg(not(target_os = "unknown"))]
impl fmt::Debug for Atom {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", repr_atom(&self))
    }
}

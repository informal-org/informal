use crate::types::*;
use crate::structs::*;
use crate::constants::*;
use crate::macros::*;
use alloc::string::String;
use alloc::borrow::Cow;


#[no_mangle]
pub extern "C" fn __av_add(env: &mut Runtime, a: u64, b: u64) -> u64 {
	// + is an overloaded operator, allowing combinations across various things
	// To prevent exponential branching, resolve both elements to Atoms and then do the math.
	let atom_a = resolve_atom!(env, a);
	let atom_b = resolve_atom!(env, b);
	println!("A {:?} B {:?}", atom_a, atom_b);
	match atom_a {
		Atom::NumericValue(f_a) => {
			match atom_b {
				Atom::NumericValue(f_b) => return (f_a + f_b).to_bits(),
				_ => return RUNTIME_ERR_EXPECTED_NUM
			}
		},
		Atom::StringValue(str_a) => {
			match atom_b {
				Atom::StringValue(str_b) => {
					let mut result_str = String::with_capacity(str_a.len() + str_b.len() + 1);
					result_str.push_str(&str_a);
					result_str.push_str(&str_b);

					let result_symbol = env.save_atom(Atom::StringValue(result_str));
					return result_symbol
				},
				_ => return RUNTIME_ERR_EXPECTED_STR
			}
		},
		_ => return RUNTIME_ERR_EXPECTED_NUM
	}
}

#[no_mangle]
pub extern "C" fn __av_sub(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	return (f_a - f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_mul(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	return (f_a * f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_div(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);

	if f_b == 0.0 {
		return RUNTIME_ERR_DIV_Z;
	}

	return (f_a / f_b).to_bits()
}


#[no_mangle]
pub extern "C" fn __av_and(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let b_bool: bool = __av_as_bool(b);
	let result: bool = a_bool && b_bool;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_or(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let b_bool: bool = __av_as_bool(b);
	let result: bool = a_bool || b_bool;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_not(_env: &mut Runtime, a: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let result: bool = !a_bool;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_gt(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a > f_b;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_gte(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a >= f_b;
	return __repr_bool(result);
}


#[no_mangle]
pub extern "C" fn __av_lt(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a < f_b;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_lte(_env: &mut Runtime, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a <= f_b;
	return __repr_bool(result);
}
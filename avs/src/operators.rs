use crate::types::*;
use crate::structs::*;
use crate::constants::*;
use crate::macros::*;
use alloc::string::String;


#[no_mangle]
pub extern "C" fn __av_add(env: &mut AvObject, a: u64, b: u64) -> u64 {
	// Add supports adding two numbers (priority) or concat strings
	match __av_typeof(a) {
		ValueType::NumericType => {
			let f_a: f64 = f64::from_bits(a);
			if f_a != f_a {
				return RUNTIME_ERR_TYPE_NAN
			}
			let f_b: f64 = valid_num!(b);
			return (f_a + f_b).to_bits()
		},
		ValueType::ObjectType => {
			// TODO: String concantanation and mixed mode unit tests.
			if __av_typeof(b) != ValueType::ObjectType {
				return RUNTIME_ERR_EXPECTED_STR;
			}
			// Verify if both are pointers to strings
			// TODO: Support for a to-string method on structs

			// TODO: Support small string constants.
			let obj_a = env.get_object(a);
			if obj_a.av_class != AV_CLASS_STRING {
				return RUNTIME_ERR_EXPECTED_STR;
			}
			let obj_b = env.get_object(b);
			if obj_b.av_class != AV_CLASS_STRING {
				return RUNTIME_ERR_EXPECTED_STR;
			}
			let str_a = obj_a.av_string.as_ref().unwrap();
			let str_b = obj_b.av_string.as_ref().unwrap();

			// IDK if the +1 is needed
			let mut result_str = String::with_capacity(str_a.len() + str_b.len() + 1);
			result_str.push_str(str_a);
			result_str.push_str(str_b);
			
			let result_obj = AvObject::new_string(result_str);
			let result_ptr = env.save_object(result_obj);

			return result_ptr
		},
		_ => {
			return RUNTIME_ERR_EXPECTED_NUM
		}
	}
}

#[no_mangle]
pub extern "C" fn __av_sub(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	return (f_a - f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_mul(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	return (f_a * f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_div(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);

	if f_b == 0.0 {
		return RUNTIME_ERR_DIV_Z;
	}

	return (f_a / f_b).to_bits()
}


#[no_mangle]
pub extern "C" fn __av_and(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let b_bool: bool = __av_as_bool(b);
	let result: bool = a_bool && b_bool;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_or(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let b_bool: bool = __av_as_bool(b);
	let result: bool = a_bool || b_bool;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_not(env: &mut AvObject, a: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let result: bool = !a_bool;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_gt(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a > f_b;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_gte(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a >= f_b;
	return __repr_bool(result);
}


#[no_mangle]
pub extern "C" fn __av_lt(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a < f_b;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_lte(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a <= f_b;
	return __repr_bool(result);
}
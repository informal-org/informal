/* 
Values in Arevel are nan-boxed. 
Floating point representation of NaN leaves a lot of bits unused. 
We pack a type and value into this space, for basic types and pointers.

0 00000001010 0000000000000000000000000000000000000000000000000000 = 64
1 11111111111 1000000000000000000000000000000000000000000000000000 = nan
Type (3 bits). Value 48 bits.
*/

// 8 = 1000
const SIGNALING_NAN: u64 = 0xFFF8_0000_0000_0000;
const QUITE_NAN: u64 = 0xFFF0_0000_0000_0000;

// Not of signaling nan. 
const VALUE_TYPE_MASK: u64 = 0x000F_0000_0000_0000;
// Clear all type bits, preserve 
const VALUE_MASK: u64 = 0x0000_FFFF_FFFF_FFFF;

const VALUE_TYPE_POINTER_MASK: u64 = 0x0009_0000_0000_0000;
const VALUE_TYPE_NONE_MASK: u64 = 0x000A_0000_0000_0000;
const VALUE_TYPE_BOOL_MASK: u64 = 0x000B_0000_0000_0000;
const VALUE_TYPE_STR_MASK: u64 = 0x000C_0000_0000_0000;

// Unused...
const VALUE_TYPE_ERR_MASK: u64 = 0x000E_0000_0000_0000;

// NaN-boxed boolean. 0xFFFB = Boolean type header.
pub const VALUE_TRUE: u64 = 0xFFFB_0000_0000_0001;
pub const VALUE_FALSE: u64 = 0xFFFB_0000_0000_0000;
pub const VALUE_NONE: u64 = 0xFFFA_0000_0000_0000;

#[derive(Debug)]
pub enum ValueType {
    NoneType, 
    BooleanType,
    NumericType,
    StringType,
	PointerType,
	ErrorType
}

#[no_mangle]
pub extern "C" fn is_nan(f: f64) -> bool {
    // By definition, any comparison with a nan returns 0. 
    // So NaNs can be identified with a self comparison.
    return f != f
}

#[no_mangle]
pub extern "C" fn __av_typeof(value: u64) -> ValueType {
	// Check if NaN boxed value
	if (value & SIGNALING_NAN) == SIGNALING_NAN {
		let type_tag = value & VALUE_TYPE_MASK;
		match type_tag {
			VALUE_TYPE_POINTER_MASK => ValueType::PointerType,
			VALUE_TYPE_NONE_MASK => ValueType::NoneType,
			VALUE_TYPE_BOOL_MASK => ValueType::BooleanType,
			VALUE_TYPE_STR_MASK => ValueType::StringType,
			VALUE_TYPE_ERR_MASK => ValueType::ErrorType,
			_ => ValueType::NumericType  		// Treat as NaN
		}
	} else {
		return ValueType::NumericType
	}
}

// TODO: Type checking
#[no_mangle]
pub extern "C" fn __av_add(a: u64, b: u64) -> u64 {
	let f_a = f64::from_bits(a);
	let f_b = f64::from_bits(b);
	return (f_a + f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_sub(a: u64, b: u64) -> u64 {
	let f_a = f64::from_bits(a);
	let f_b = f64::from_bits(b);
	return (f_a - f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_mul(a: u64, b: u64) -> u64 {
	let f_a = f64::from_bits(a);
	let f_b = f64::from_bits(b);
	return (f_a * f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_div(a: u64, b: u64) -> u64 {
	let f_a = f64::from_bits(a);
	let f_b = f64::from_bits(b);
	return (f_a / f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_as_bool(a: u64) -> bool {
	// TODO: More advanced type checking.
	if a == VALUE_TRUE {
		return true
	}
	if a == VALUE_FALSE {
		return false;
	}
	// Truthiness for other empty types and errors.
	// todo: verify this doesn't happen
	return false;
}

pub extern "C" fn __repr_bool(a: bool) -> u64 {
	if a {
		return VALUE_TRUE
	} 
	else {
		return VALUE_FALSE
	}
}

#[no_mangle]
pub extern "C" fn __av_and(a: u64, b: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let b_bool: bool = __av_as_bool(b);
	let result: bool = a_bool && b_bool;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_or(a: u64, b: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let b_bool: bool = __av_as_bool(b);
	let result: bool = a_bool || b_bool;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_not(a: u64) -> u64 {
	let a_bool: bool = __av_as_bool(a);
	let result: bool = !a_bool;
	return __repr_bool(result);
}


// Placeholder function. The body of the compiled WAT version of this
// will be linked with application code.
#[no_mangle]
pub extern "C" fn _start() -> u64 {
	0
}

/* 
Values in Arevel are nan-boxed. 
Floating point representation of NaN leaves a lot of bits unused. 
We pack a type and value into this space, for basic types and pointers.

0 00000001010 0000000000000000000000000000000000000000000000000000 = 64
1 11111111111 1000000000000000000000000000000000000000000000000000 = nan
Type (3 bits). Value 48 bits.
*/

// #![feature(lang_items)]
// #![no_std]
// #![feature(alloc)]

pub mod error;
use core::slice;
use error::{ArevelError};

use core::fmt::{Write, self};
use core::panic::PanicInfo;

extern crate alloc;
use alloc::vec::Vec;
use alloc::boxed::Box;

extern crate wee_alloc;

// Use `wee_alloc` as the global allocator.
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;


// 8 = 1000
const SIGNALING_NAN: u64 = 0xFFF8_0000_0000_0000;
const QUITE_NAN: u64 = 0xFFF0_0000_0000_0000;

// Not of signaling nan. 
const VALUE_TYPE_MASK: u64 = 0x000F_0000_0000_0000;
// Clear all type bits, preserve. 
// Mask with 0000 rather than 0007 for the nice letter codes.
const VALUE_MASK: u64 = 0x0000_FFFF_FFFF_FFFF;

// D,F Currenty unsed... 0-8 Invalid NaN (Do Not Use)
const VALUE_TYPE_POINTER_MASK: u64 = 0x0009_0000_0000_0000;
const VALUE_TYPE_NONE_MASK: u64 = 0x000A_0000_0000_0000;
const VALUE_TYPE_BOOL_MASK: u64 = 0x000B_0000_0000_0000;
const VALUE_TYPE_STR_MASK: u64 = 0x000C_0000_0000_0000;
const VALUE_TYPE_ERR_MASK: u64 = 0x000E_0000_0000_0000;

// NaN-boxed boolean. 0xFFFB = Boolean type header.
pub const VALUE_TRUE: u64 = 0xFFFB_0000_0000_0001;
pub const VALUE_FALSE: u64 = 0xFFFB_0000_0000_0000;
pub const VALUE_NONE: u64 = 0xFFFA_0000_0000_0000;

// Private - temprorary error code.
// Future will contain payload of error region.
const VALUE_ERR: u64 = 0xFFFE_0000_0000_0000;

#[derive(Debug,PartialEq)]
pub enum ValueType {
    NoneType, 
    BooleanType,
    NumericType,
    StringType,
	PointerType,
	ErrorType
}

#[cfg(target_os = "unknown")]
extern {
	// Injection point for Arevel code. 
	// This will be removed during linking phase.
    fn __av_inject_placeholder();
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_nan(f: f64) -> bool {
    // By definition, any comparison with a nan returns 0. 
    // So NaNs can be identified with a self comparison.
    return f != f
}

macro_rules! validate_type {
	($v:expr, $t:expr) => ({
		if __av_typeof($v) != $t {
			return VALUE_ERR;
		}
	})
}

macro_rules! disallow_nan {
	($f_a:expr, $f_b: expr) => {
		if $f_a != $f_a || $f_b != $f_b {
			return VALUE_ERR;
		}
	}
}

macro_rules! valid_num {
	($val:expr) => ({
		if __av_typeof($val) != ValueType::NumericType {
			return VALUE_ERR
		}
		let f_val = f64::from_bits($val);
		// Disallow nan
		if f_val != f_val {
			return VALUE_ERR
		}
		f_val
	})
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

#[no_mangle]
pub extern "C" fn __av_add(a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	return (f_a + f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_sub(a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	return (f_a - f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_mul(a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	return (f_a * f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_div(a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);

	if f_b == 0.0 {
		return VALUE_ERR;
	}

	return (f_a / f_b).to_bits()
}

#[no_mangle]
pub extern "C" fn __av_as_bool(a: u64) -> bool {
	// TODO: More advanced type checking.
	if a == VALUE_TRUE {
		return true
	}
	if a == VALUE_FALSE || a == VALUE_NONE {
		return false;
	}
	// Truthiness for other empty types and errors.
	let a_type = __av_typeof(a);
	match a_type {
		ValueType::NumericType => {
			let f_a = f64::from_bits(a);
			return f_a != 0.0;
		} 
		ValueType::ErrorType => {
			// Does treating error as false have other consequences?
			// What about not (1 / 0) being treated as true
			return false;
		}
		_ => {
			// TODO
			return false
		}
	}
}

#[inline(always)]
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

#[no_mangle]
pub extern "C" fn __av_gt(a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a > f_b;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_gte(a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a >= f_b;
	return __repr_bool(result);
}


#[no_mangle]
pub extern "C" fn __av_lt(a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a < f_b;
	return __repr_bool(result);
}

#[no_mangle]
pub extern "C" fn __av_lte(a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	let result = f_a <= f_b;
	return __repr_bool(result);
}

#[no_mangle]
#[inline(never)]
pub extern "C" fn __av_malloc(size: u32) -> *const u64 {
	// Size in # of u64 values to store.
	// This function should be called by the host system to allocate a region of memory
	// before passing in any data to the WASM instance. 
	// Otherwise, we risk data clobbering each other and exposing regions of memory.
	let mut arr: Vec<u64> = Vec::with_capacity( size as usize );
	for _i in 0..size {
    	arr.push(0);
	}

	// return Box::into_raw(Box::new(contiguous_mem)) as u32
	let mut contiguous_mem = arr.into_boxed_slice();
	contiguous_mem[0] = 23;
	contiguous_mem[1] = 42;

	// NOTE: This MUST be freed explicitly by the caller.
	let contiguous_mem_ptr = Box::leak(contiguous_mem);
	return &(contiguous_mem_ptr[0]) as *const u64
}

// #[no_mangle]
// // pub extern "C" fn __av_free(ptr: *mut u32) {
#[no_mangle]
#[inline(never)]
pub extern "C" fn __av_free(ptr: *const u64, size: usize) {
	// Free memory allocated by __av_malloc. Should only be called once.
	unsafe { 
		let slice_ptr = slice::from_raw_parts_mut(ptr as *mut u64, size);
		let slice_box = Box::from_raw(slice_ptr);
		drop(slice_box);
	};
}

#[no_mangle]
#[inline(never)]
fn __av_save(results: &mut Vec<u64>, id: usize, value: u64) { 
	results[id] = value;
}

#[no_mangle]
#[cfg(target_os = "unknown")]
pub extern "C" fn __av_run(size: u32) -> u32 {
	// Note: This is tied to the generated symbol in the linker.	
	let mut results: Vec<u64> = Vec::with_capacity(size as usize);
	for _i in 0..size {
		results.push(0)
	}

	unsafe {
		__av_inject_placeholder();
	}

	// return Box::into_raw(Box::new(out)) as u32;
	// return Box::into_raw(Box::new(env.cells.into_boxed_slice())) as u32;
	return (&results[0] as *const u64) as u32;
}


// #[cfg(test)]
// mod tests {
// 	use super::*;

// 	unsafe fn get_slice<'a>(ptr: *const u64, size: usize) -> &'a [u64] {
// 		let slice: [usize; 2] = [ptr as usize, size];
// 		let slice_ptr = &slice as * const _ as *const () as *const &[u64];
// 		*slice_ptr
// 	}

// 	#[test]
//     fn test_as_bool() {
// 		assert_eq!(__av_as_bool(VALUE_TRUE), true);
// 		assert_eq!(__av_as_bool(VALUE_FALSE), false);
// 		assert_eq!(__av_as_bool(VALUE_NONE), false);
// 		assert_eq!(__av_as_bool(VALUE_ERR), false);
// 		assert_eq!(__av_as_bool(f64::to_bits(1.0)), true);
// 		assert_eq!(__av_as_bool(f64::to_bits(3.0)), true);
// 		assert_eq!(__av_as_bool(f64::to_bits(0.0)), false);
// 		assert_eq!(__av_as_bool(f64::to_bits(-0.0)), false);
// 	}

// 	#[test]
//     fn test_mem() {
// 		// Verify no panic on any of these operations
// 		let ptr = __av_malloc(4);
// 		println!("Memory address: {:?}", ptr);
// 		let points_at = unsafe {
// 			println!("Value at: {:?}", *ptr);
// 			println!("Values: {:?}", slice::from_raw_parts(ptr, 4));
// 			*ptr
// 		};

// 		unsafe {
// 			println!("out: {:?}", get_slice(ptr, 2));
// 		}
// 		__av_free(ptr, 4);
// 	}
// }
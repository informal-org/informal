#![no_main]
#![no_std]

pub mod constants;
pub mod structs;
pub mod macros;
pub mod utils;
#[allow(non_snake_case)]
pub mod avfb_generated;

use constants::*;
use structs::*;

#[allow(non_snake_case)]
pub use crate::avfb_generated::avfb::{AvFbObj, AvFbObjArgs, get_root_as_av_fb_obj};



extern crate wee_alloc;

// Use `wee_alloc` as the global allocator.
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;



extern crate flatbuffers;
extern crate alloc;
use alloc::vec::Vec;
use alloc::boxed::Box;
use alloc::string::String;
use core::cell::RefCell;
use core::slice;


#[cfg(target_os = "unknown")]
extern {
	// Injection point for Arevel code. 
	// This will be removed during linking phase.
	#[inline(never)]
    fn __av_inject_placeholder();
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_nan(f: f64) -> bool {
    // By definition, any comparison with a nan returns 0. 
    // So NaNs can be identified with a self comparison.
    return f != f
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_truthy(value: u64) -> bool {
    if value & VALHEAD_TRUTHY_MASK == VALHEAD_TRUTHY_MASK {
		// For NaN boxed values, use the truthy bit.
		return true;
	} else {
		// Otherwise, floating point 0, -0, NaN is false, everything else is true
		let f_value: f64 = f64::from_bits(value);
		// TODO: Test case to verify compiler doesn't "optimize" this away
		return f_value > 0.0 || f_value < 0.0;
	}
}


#[no_mangle]
#[inline(always)]
pub extern "C" fn is_object(value: u64) -> bool {
    return (value & VALHEAD_OBJTYPE_MASK) == VALHEAD_OBJTYPE_MASK;
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_string(value: u64) -> bool {
	// Check if NaN bits are set and obj mask bit unset.
	// Objtype mask bit is 0 for empty string, small string or string pointer.
    return (value & SIGNALING_NAN) == SIGNALING_NAN && (value & VALHEAD_OBJTYPE_MASK) != VALHEAD_OBJTYPE_MASK;
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_symbol(value: u64) -> bool {
    return (value & VALHEAD_REFTYPE_MASK) == VALHEAD_REFTYPE_MASK;
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_pointer(value: u64) -> bool {
    return (value & SIGNALING_NAN) == SIGNALING_NAN && (value & VALHEAD_REFTYPE_MASK) != VALHEAD_REFTYPE_MASK;
}


#[no_mangle]
// Use this only returning type info.
// Use the dedicated is_* function to check type more efficiently.
pub extern "C" fn __av_typeof(value: u64) -> ValueType {
	if (value & SIGNALING_NAN) == SIGNALING_NAN {
		if (value & VALHEAD_OBJTYPE_MASK) != VALHEAD_OBJTYPE_MASK {
			return ValueType::StringType;
		} else {
			let valhead = value & VALHEAD_MASK;

			match valhead {
				// Symbol to something truthy
				// TODO: Remove None & Bool from type options
				VALUE_T_SYM_OBJ => return ValueType::SymbolType,
				VALUE_T_PTR_OBJ => return ValueType::PointerType, 
				VALUE_F_SYM_OBJ => return ValueType::SymbolType,
				VALUE_F_PTR_OBJ => return ValueType::ErrorType,
				_ => return ValueType::NumericType  // Treat other values as NaN
			}
		}
	} else {
		return ValueType::NumericType
	}
}



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
		ValueType::PointerType => {
			// TODO: String concantanation and mixed mode unit tests.
			if __av_typeof(b) != ValueType::PointerType {
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
pub extern "C" fn __av_as_bool(a: u64) -> bool {
	// TODO: More advanced type checking.
	
	// TODO: Use truthyness bit instead
	if a == SYMBOL_TRUE {
		return true
	}
	if a == SYMBOL_FALSE || a == SYMBOL_NONE {
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
		return SYMBOL_TRUE
	} 
	else {
		return SYMBOL_FALSE
	}
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

#[no_mangle]
pub extern "C" fn __av_read_obj(ptr: u32, size: u32) -> String {
	// The host system will call malloc and write to this memory location
	// Then inject in a call to read from it. 
	// Problem - how do we do that at link-time?
	return String::from("hello")
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

	let mut contiguous_mem = arr.into_boxed_slice();
	// contiguous_mem[0] = 23;
	// contiguous_mem[1] = 42;

	// NOTE: This MUST be freed explicitly by the caller.
	let contiguous_mem_ptr = Box::leak(contiguous_mem);
	return &(contiguous_mem_ptr[0]) as *const u64
}



#[no_mangle]
#[inline(never)]
pub extern "C" fn __av_sized_ptr(ptr: u32, size: u32) -> *const u32 {
	// Size in # of u64 values to store.
	// This function should be called by the host system to allocate a region of memory
	// before passing in any data to the WASM instance. 
	// Otherwise, we risk data clobbering each other and exposing regions of memory.
	let mut arr: Vec<u32> = Vec::with_capacity( 4 as usize );
	arr.push(ptr);
	arr.push(size);

	let mut contiguous_mem = arr.into_boxed_slice();
	contiguous_mem[0] = ptr;
	contiguous_mem[1] = size;

	// NOTE: This MUST be freed explicitly by the caller.
	let contiguous_mem_ptr = Box::leak(contiguous_mem);
	return &(contiguous_mem_ptr[0]) as *const u32
}


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

// TODO init function for values since we save stuff in random order.
// pub extern "C" fn __av_init(env: &mut AvObject, size: usize) {
// 	let results = env.
// 	for i in 0..size {
		
// 	}
// }

#[no_mangle]
#[inline(never)]
// pub extern "C" fn __av_save(results: &mut Vec<u64>, id: usize, value: u64) { 
pub extern "C" fn __av_save(env: &mut AvObject, id: usize, value: u64) { 
	env.save_value(id, value);
}


#[no_mangle]
#[inline(never)]
pub extern "C" fn __av_get(env: &mut AvObject, id: usize) -> u64 { 
	return env.get_value(id);
}

// #[no_mangle]
// #[inline(never)]
// pub extern "C" fn __av_get_obj(env: &mut AvObject, id: usize) -> u64 { 
// 	return env.save_value;
// }

#[no_mangle]
#[inline(never)]
#[cfg(target_os = "unknown")]
pub extern "C" fn __av_inject(env: &mut AvObject) {
	// __av_save(results, 0, 0);
	// __av_get(results, 0);

	unsafe {
		__av_inject_placeholder();
	}
}

#[no_mangle]
#[inline(never)]
#[cfg(target_os = "unknown")]
pub extern "C" fn __av_run() -> u32 {
	// Note: This is tied to the generated symbol in the linker.
	let mut env = AvObject::new_env();

	// Done this way to prevent the compiler from inlining the injection point 
	// multiple times with allocations
	__av_inject(&mut env);


	// let mut builder = flatbuffers::FlatBufferBuilder::new_with_capacity(1024);
    // let hello = builder.create_string("Hello Arevellllllllllllllllll were werwerw ");
	// let shared_vec: Vec<u64> = Vec::new();
	// let results_vec = builder.create_vector(&shared_vec);

	// let spring = builder.create_string("Spring");

	// let obj2 = AvFbObj::create(&mut builder, &AvFbObjArgs{
	// 	id: 0,
	// 	av_class: 0,
	// 	av_values: None,
	// 	av_objects: None,
	// 	av_string: Some(spring)
    // });

	// let mut obj_vector: Vec<flatbuffers::WIPOffset<AvFbObj>> = Vec::new();
	// obj_vector.push(obj2);
	// let avobjs = builder.create_vector(&obj_vector);
	// // let avobjs = builder.create_vector(&obj_vector);

    // let obj = AvFbObj::create(&mut builder, &AvFbObjArgs{
	// 	id: 0,
	// 	av_class: 0,
	// 	av_values: Some(results_vec),
	// 	av_objects: Some(avobjs),
    //     av_string: Some(hello)
    // });

	// builder.finish(obj, None);

	// let buf = builder.finished_data(); 		// Of type `&[u8]`


	// let ptr = (&buf[0] as *const u8) as u32;
	// let size = buf.len() as u32;
	// return __av_sized_ptr(ptr, size) as u32
	return 0;
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
// 		assert_eq!(__av_as_bool(SYMBOL_TRUE), true);
// 		assert_eq!(__av_as_bool(SYMBOL_FALSE), false);
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
pub mod constants;
pub mod structs;
pub mod macros;
#[allow(non_snake_case)]
pub mod avfb_generated;

use constants::*;
use structs::*;
#[allow(non_snake_case)]
pub use crate::avfb_generated::avfb::{AvFbObj, AvFbObjArgs, get_root_as_av_fb_obj, AvFbObjType};

extern crate flatbuffers;
extern crate alloc;
use alloc::vec::Vec;
use alloc::boxed::Box;
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
pub extern "C" fn __av_add(env: &mut AvObject, a: u64, b: u64) -> u64 {
	let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);
	return (f_a + f_b).to_bits()
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

#[inline(always)]
pub extern "C" fn __repr_pointer(ptr: usize) -> u64 {
	let masked_ptr: u64 = SIGNALING_NAN | VALUE_TYPE_POINTER_MASK | (ptr as u64);
	return masked_ptr
}

#[inline(always)]
pub extern "C" fn __unwrap_pointer(masked_ptr: u64) -> usize {
	// Clear NaN bits & pointer mask to extract pointer values
	let ptr: u64 = masked_ptr & VALUE_MASK;
	println!("Returning unwraped pointer to {:?} = {:?}", ptr, masked_ptr);
	return ptr as usize;
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


	let mut builder = flatbuffers::FlatBufferBuilder::new_with_capacity(1024);
    let hello = builder.create_string("Hello Arevellllllllllllllllll were werwerw ");
	let shared_vec: Vec<u64> = Vec::new();
	let results_vec = builder.create_vector(&shared_vec);

	let spring = builder.create_string("Spring");

	let obj2 = AvFbObj::create(&mut builder, &AvFbObjArgs{
		avtype: AvFbObjType::AvObject,
		avclass: 0,
		avhash: 0,
		values: None,
        avstr: Some(spring),
		length: 0,
		avbytes: None,
		avobjs: None
    });

	let mut obj_vector: Vec<flatbuffers::WIPOffset<AvFbObj>> = Vec::new();
	obj_vector.push(obj2);
	let avobjs = builder.create_vector(&obj_vector);
	// let avobjs = builder.create_vector(&obj_vector);


    let obj = AvFbObj::create(&mut builder, &AvFbObjArgs{
		avtype: AvFbObjType::AvObject,
		avclass: 0,
		avhash: 0,
		values: Some(results_vec),
        avstr: Some(hello),
		length: 0,
		avbytes: None,
		avobjs: Some(avobjs)
    });

	builder.finish(obj, None);

	let buf = builder.finished_data(); 		// Of type `&[u8]`


	let ptr = (&buf[0] as *const u8) as u32;
	let size = buf.len() as u32;
	return __av_sized_ptr(ptr, size) as u32
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
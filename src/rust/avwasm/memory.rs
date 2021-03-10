use alloc::vec::Vec;
use alloc::boxed::Box;
use alloc::string::String;
use core::slice;

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

// #![no_main]
// #![no_std]

pub mod constants;
pub mod structs;
#[macro_use]
pub mod macros;
pub mod utils;
pub mod types;
pub mod memory;
pub mod operators;
#[allow(non_snake_case)]
pub mod avfb_generated;

// use constants::*;
use structs::*;
#[cfg(target_os = "unknown")]
use memory::{__av_sized_ptr};
// use types::*;
// use operators::*;

// use utils::*;

extern crate alloc;
extern crate wee_alloc;
extern crate flatbuffers;

#[allow(non_snake_case)]
pub use crate::avfb_generated::avfb::{AvFbObj, AvFbObjArgs, get_root_as_av_fb_obj};

// Use `wee_alloc` as the global allocator.
// #[global_allocator]
// static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;




#[cfg(target_os = "unknown")]
extern {
	// Injection point for Arevel code. 
	// This will be removed during linking phase.
	#[inline(never)]
    fn __av_inject_placeholder();
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
    let hello = builder.create_string("Hello Arevel");
	let shared_vec: Vec<u64> = Vec::new();
	let results_vec = builder.create_vector(&shared_vec);

	let spring = builder.create_string("Spring");

	let obj2 = AvFbObj::create(&mut builder, &AvFbObjArgs{
		id: 0,
		av_class: 0,
		av_values: None,
		av_objects: None,
		av_string: Some(spring)
    });

	let mut obj_vector: Vec<flatbuffers::WIPOffset<AvFbObj>> = Vec::new();
	obj_vector.push(obj2);
	let avobjs = builder.create_vector(&obj_vector);
	// let avobjs = builder.create_vector(&obj_vector);

    let obj = AvFbObj::create(&mut builder, &AvFbObjArgs{
		id: 0,
		av_class: 0,
		av_values: Some(results_vec),
		av_objects: Some(avobjs),
        av_string: Some(hello)
    });

	builder.finish(obj, None);

	let buf = builder.finished_data(); 		// Of type `&[u8]`


	let ptr = (&buf[0] as *const u8) as u32;
	let size = buf.len() as u32;
	return __av_sized_ptr(ptr, size) as u32
}


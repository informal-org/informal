

pub fn as_u32(array: &[u8; 4]) -> u32 {
    // WASM is always little endian.
    ((array[0] as u32) <<  0) |
    ((array[1] as u32) <<  8) |
    ((array[2] as u32) << 16) |
    ((array[3] as u32) << 24)
}



#[macro_export]
macro_rules! decode_values {
    // Defined as a macro so it's all within the same lifetime of caller
    ($memory_view:expr, $ptr:expr, $length:expr) => ({
        // Decode N values from memory. 
        // Assume they're all 64 bytes long and memory is aligned.

        // let index = $ptr / 8;
        // let byte_alignment = $ptr % 8;
        // if byte_alignment != 0 {
        //     // TODO: Raise error
        //     panic!("Unexpected, Arevel WASM unaligned memory access!");
        //     // return 0;
        // }
        // println!("index: {:?} Remainder: {:?}", index, byte_alignment);

        // let ref_start = $ptr as usize;
        // let ref_end = ($ptr + 4);
        
        // // Return decoded values to macro caller
        // let ref_bytes = $memory_view.get(ref_start..ref_end).unwrap();
        
        // let mut a: [u8; 4] = Default::default();
        // a.copy_from_slice(&ref_bytes[0..4]);
        // let ref_ptr = as_u32(a);

        // println!("ref ptr {:X}", ref_ptr);
        // let mut b: [u8; 4] = Default::default();
        // b.copy_from_slice(&ref_bytes[4..8]);
        // let ref_size = as_u32(b);
        // println!("ref size {:X}", ref_size);

        // // for i in start..end {
        // //     println!("Values {:?}", mem_view.get(i));
        // // }


        // // println!("Values {:?}", result);
        // result
    });
}


#[macro_export]
macro_rules! decode_flatbuf {
    // Defined as a macro so it's all within the same lifetime of caller
    ($memory:expr, $ptr:expr, $length:expr) => {{
        // We need to read the flatbuffer contents, but since web assembly only supports
        // returning one value, we first send back the pointer, size pair and then decode the buffer
        let memory_view32: MemoryView<u32> = $memory.view();
        let sized_ptr_index = ($ptr / 4);
        
        let ref_ptr = memory_view32.get(sized_ptr_index as usize).unwrap().get() as usize;
        let ref_size = memory_view32.get( (sized_ptr_index + 1) as usize).unwrap().get() as usize;

        let memory_view8: MemoryView<u8> = $memory.view();
        let fb_ref = memory_view8.get(ref_ptr..(ref_ptr + ref_size)).unwrap();

        // Note: This does a memory copy. That's the safe version.
        // We can look at an unsafe pointer version later on with additional verification.
        let fb_bytes: Vec<u8> = fb_ref.iter().map(|cell| cell.get()).collect();

        // println!("{:?}", fb_bytes);
        let fb = get_root_as_avobj(&fb_bytes);

        println!("Flatbuffer {:?}", fb);

        // let result: Vec<u8> = Vec::new();
        // result
        // fb
        let objects = fb.avobjs().unwrap();
        println!("objs: {:?}", objects.get(0));
        println!("obj str: {:?}", objects.get(0).avstr());

        let values = fb.values().unwrap();
        // Perform another copy of the data - due to ownership rules
        let mut results: Vec<u64> = Vec::with_capacity(values.len() as usize);
        for cell_idx in 0..values.len() {
            results.push(values.get(cell_idx));
        }

        results
        // values.clone();
    }}
}

// BUF [20, 0, 0, 0, 16, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 16, 0, 0, 0, 4, 0, 0, 0, 12, 0, 0, 0, 72, 101, 108, 108, 111, 32, 65, 114, 101, 118, 101, 108, 0, 0, 0, 0]
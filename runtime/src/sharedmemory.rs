

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
    ($memory:expr, $ptr:expr, $length:expr) => ({
        let memory_view32: MemoryView<u32> = $memory.view();
        let index = ($ptr / 4);
        
        let start = index as usize;
        let end = (index + 2) as usize;
        
        // Return decoded values to macro caller
        // let ref_bytes = .unwrap() as &[u8];

        // let ref_bytes: Vec<_> = memory_view32.get((ref_start as usize)..(ref_end as usize)).unwrap().to_vec();

        let ref_ptr = memory_view32.get(start).unwrap().get() as usize;
        let ref_size = memory_view32.get(start + 1).unwrap().get() as usize;
        println!("{:?} size {:?}", ref_ptr, ref_size);


        let memory_view8: MemoryView<u8> = $memory.view();
        let fb_ref = memory_view8.get(ref_ptr..(ref_ptr + ref_size)).unwrap();

        // Note: This does a memory copy. That's the safe version.
        // We can look at an unsafe pointer version later on with additional verification.
        let fb_bytes: Vec<u8> = fb_ref.iter().map(|cell| cell.get()).collect();

        println!("{:?}", fb_bytes);

        let fb = get_root_as_avobj(&fb_bytes);

        println!("Flatbuffer {:?}", fb);

        println!("Str: {:?}", fb.avstr());

        // let ref_ptr = memory_view32.get( ($ptr / 4) as usize );
        // println!("ref ptr {:?}", ref_ptr);
        // println!("ref start {:?}", ref_start);

        // let ref_size = memory_view32.get( (($ptr / 4) + 1) as usize );
        // println!("ref size {:?}", ref_size);

        


        // for i in start..end {
        //     println!("Values {:?}", mem_view.get(i));
        // }


        // println!("Values {:?}", result);
        //let start = ref_ptr as usize;
        //let end = (ref_ptr + ref_size) as usize;


        // let result = $memory_view.get(start..end).unwrap();
        // for i in start..end {
        //     println!("Values {:?}", $memory_view.get(i));
        // }
        let result: Vec<u8> = Vec::new();

        result

    })
}

// BUF [20, 0, 0, 0, 16, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 16, 0, 0, 0, 4, 0, 0, 0, 12, 0, 0, 0, 72, 101, 108, 108, 111, 32, 65, 114, 101, 118, 101, 108, 0, 0, 0, 0]
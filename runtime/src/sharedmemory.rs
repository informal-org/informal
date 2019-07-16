
#[macro_export]
macro_rules! decode_values {
    // Defined as a macro so it's all within the same lifetime of caller
    ($memory_view:expr, $ptr:expr, $length:expr) => ({
        // Decode N values from memory. 
        // Assume they're all 64 bytes long and memory is aligned.

        let index = $ptr / 8;
        let byte_alignment = $ptr % 8;
        if byte_alignment != 0 {
            // TODO: Raise error
            panic!("Unexpected, Arevel WASM unaligned memory access!");
            // return 0;
        }
        // println!("index: {:?} Remainder: {:?}", index, byte_alignment);

        let start = index as usize;
        let end = (index + $length) as usize;

        // Return decoded values to macro caller
        let result = $memory_view.get(start..end).unwrap();
        // for i in start..end {
        //     println!("Values {:?}", mem_view.get(i));
        // }

        // println!("Values {:?}", result);
        result
    });
}


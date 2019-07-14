use wasmer_runtime::memory::MemoryView;
use wasmer_runtime::{Instance};

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


#[macro_export]
macro_rules! decode_deref {
    ($memory_view:expr, $ptr:expr) => ({
        // Reads from a boxed indirect of length, pointer
        let boxed_pointer = decode_values!($memory_view, $ptr, 2);

        let length = boxed_pointer[0].get();
        let reference = boxed_pointer[1].get();
        println!("Reference {:?} Length: {:?}", reference, length);

        let result = decode_values!($memory_view, reference, length);
        
        result
    })
}
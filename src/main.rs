extern crate runtime;

use runtime::repl;

// use std::str;
use std::io::{stdin,stdout,Write};

use avs::constants::{VALUE_TYPE_POINTER_MASK};


extern crate flatbuffers;
pub use avs::avobj_generated::avsio::{AVObj, AVObjArgs, get_root_as_avobj};


fn repl_it() {
    loop {
        print!("> ");
        let _=stdout().flush();
        let reader = stdin();
        let mut input = String::new();
        reader.read_line(&mut input).ok().expect("Failed to read line");

        repl::read_eval_print(input);
    }
}


fn main() {
    println!("Arevel - Version - 1.0");
    // repl_it();
    // eval_wat();

    let mut builder = flatbuffers::FlatBufferBuilder::new_with_capacity(1024);
    let hello = builder.create_string("Hello Arevel");

    let obj = AVObj::create(&mut builder, &AVObjArgs{
        id: 9,
        name: Some(hello), 
        value: 42
    });

    println!("{:?}", obj);

    builder.finish(obj, None);

    println!("{:?}", obj);

    let buf = builder.finished_data(); // Of type `&[u8]`

    println!("{:?}", buf);

    let input = get_root_as_avobj(buf);

    println!("INput: {:?}", input);
    println!("id: {:?}", input.id());
    println!("name: {:?}", input.name());
    println!("value: {:?}", input.value());


    println!("{:X}", VALUE_TYPE_POINTER_MASK);
}

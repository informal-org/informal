extern crate runtime;

// use runtime::repl;

// use std::str;
use std::io::{stdin,stdout,Write};

use avs::constants::*;

extern crate flatbuffers;
// pub use avs::avfb_generated::avfb::{AvFbObj, AvFbObjArgs, get_root_as_av_fb_obj};


// fn repl_it() {
//     loop {
//         print!("> ");
//         let _=stdout().flush();
//         let reader = stdin();
//         let mut input = String::new();
//         reader.read_line(&mut input).ok().expect("Failed to read line");

//         repl::read_eval_print(input);
//     }
// }


fn main() {
    println!("Arevel - Version - 0.0");
    // repl_it();
    // eval_wat();

    // let mut builder = flatbuffers::FlatBufferBuilder::new_with_capacity(1024);
    // let hello = builder.create_string("Hello Arevel");

    // let obj = AVObj::create(&mut builder, &AVObjArgs{
    //     id: 9,
    //     name: Some(hello), 
    //     value: 42
    // });


	// let mut builder = flatbuffers::FlatBufferBuilder::new_with_capacity(1024);
    // let hello = builder.create_string("Hello Arevel");

    // let obj = AvFbObj::create(&mut builder, &AvFbObjArgs{
    //     id: 0,
	// 	av_class: AV_CLASS_STRING,
	// 	av_values: None,
    //     av_objects: None,
    //     av_string: Some(hello)
    // });

    // println!("{:?}", obj);
    // // println!("raw str data {:?}", obj.1.avstr());

	// builder.finish(obj, None);

	// let buf = builder.finished_data(); 		// Of type `&[u8]`    

    // println!("OBJ {:?}", obj);
    // println!("BUF {:?}", buf);

    // let input = get_root_as_avobj(buf);

    // println!("INput: {:?}", input);
    // println!("id: {:?}", input.id());
    // println!("name: {:?}", input.name());
    // println!("value: {:?}", input.value());
}

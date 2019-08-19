use crate::structs::Atom;
use crate::structs::Runtime;

use crate::constants::*;
use crate::types::*;


#[derive(Clone)]
pub enum NativeFn {
    Fn1(NativeFn1),
    Fn2(NativeFn2),
    Fn3(NativeFn3),
    // Fn4(NativeFn4),
    // Fn5(NativeFn5),
}

impl PartialEq for NativeFn {
    fn eq(&self, other: &Self) -> bool {
        return false;
    }
}

trait Callable {
    fn call(&self, env: &mut Runtime, args: Vec<u64>) -> u64;
}

#[derive(Clone)]
pub struct NativeFn1 {
    pub func: fn(&mut Runtime, u64) -> u64
}

impl NativeFn1 {
    pub fn create_atom(func: fn(&mut Runtime, u64) -> u64) -> Atom {
        return Atom::FunctionValue(NativeFn::Fn1(NativeFn1 {
            func: func
        }))
    }
}


#[derive(Clone)]
pub struct NativeFn2 {
    pub func: fn(&mut Runtime, u64, u64) -> u64
}

impl NativeFn2 {
    pub fn create_atom(func: fn(&mut Runtime, u64, u64) -> u64) -> Atom {
        return Atom::FunctionValue(NativeFn::Fn2(NativeFn2 {
            func: func
        }))
    }
}


#[derive(Clone)]
pub struct NativeFn3 {
    pub func: fn(&mut Runtime, u64, u64, u64) -> u64
}

// #[derive(Clone)]
// pub struct NativeFn4 {
//     func: fn(&mut Runtime, u64, u64, u64, u64) -> u64
// }

// #[derive(Clone)]
// pub struct NativeFn5 {
//     func: fn(&mut Runtime, u64, u64, u64, u64, u64) -> u64
// }


impl Callable for NativeFn1 {
    fn call(&self, mut env: &mut Runtime, args: Vec<u64>) -> u64 {
        // TODO: Check arity
        return (self.func)(&mut env, args[0]);
    }
}

impl Callable for NativeFn2 {
    fn call(&self, mut env: &mut Runtime, args: Vec<u64>) -> u64 {
        // TODO: Check arity
        return (self.func)(&mut env, args[0], args[1])
    }
}

impl Callable for NativeFn3 {
    fn call(&self, mut env: &mut Runtime, args: Vec<u64>) -> u64 {
        // TODO: Check arity
        return (self.func)(&mut env, args[0], args[1], args[2])
    }
}

pub fn __av_min(_env: &mut Runtime, a: u64, b: u64) -> u64 {
    let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);

    return f_a.min(f_b).to_bits();
}

pub fn __av_max(_env: &mut Runtime, a: u64, b: u64) -> u64 {
    let f_a: f64 = valid_num!(a);
	let f_b: f64 = valid_num!(b);

    return f_a.max(f_b).to_bits();
}

pub fn __av_abs(_env: &mut Runtime, a: u64) -> u64 {
    let f_a: f64 = valid_num!(a);
    return f_a.abs().to_bits();
}

pub fn __av_ceil(_env: &mut Runtime, a: u64) -> u64 {
    let f_a: f64 = valid_num!(a);
    return f_a.ceil().to_bits();
}

pub fn __av_floor(_env: &mut Runtime, a: u64) -> u64 {
    let f_a: f64 = valid_num!(a);
    return f_a.floor().to_bits();
}

pub fn __av_truncate(_env: &mut Runtime, a: u64) -> u64 {
    let f_a: f64 = valid_num!(a);
    return f_a.trunc().to_bits();
}

pub fn __av_round(_env: &mut Runtime, a: u64) -> u64 {
    let f_a: f64 = valid_num!(a);
    return f_a.round().to_bits();
}

pub fn __av_sqrt(_env: &mut Runtime, a: u64) -> u64 {
    let f_a: f64 = valid_num!(a);
    return f_a.sqrt().to_bits();
}

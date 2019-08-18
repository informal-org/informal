use crate::structs::Runtime;


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
    func: fn(&mut Runtime, u64) -> u64
}

#[derive(Clone)]
pub struct NativeFn2 {
    func: fn(&mut Runtime, u64, u64) -> u64
}

#[derive(Clone)]
pub struct NativeFn3 {
    func: fn(&mut Runtime, u64, u64, u64) -> u64
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
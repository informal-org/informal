use core::cell::RefCell;

#[derive(Debug,PartialEq)]
pub enum ValueType {
    NoneType, 
    BooleanType,
    NumericType,
    StringType,
	PointerType,
	ErrorType
}

pub enum AvObjectType {
    AvObject,
    AvString,
    AvEnvironment,
    // AvClass, AvFunction
}

// Matches with the IO object format. The fields present vary based on object type.
pub struct AvObject {
    pub avtype: AvObjectType,
    pub avclass: u32,
    pub avhash: u64,
    pub length: u32,
    pub values: RefCell<Option<Vec<u64>>>,
    pub avstr: Option<String>,     // TOXO: &str vs str vs String
    pub avbytes: RefCell<Option<Vec<u8>>>,
    pub avobjs: RefCell<Option<Vec<AvObject>>>
}

impl AvObject {
    pub fn new_env() -> AvObject {
        let mut results: Vec<u64> = Vec::new();
        let mut obj_vec: Vec<AvObject> = Vec::new();

        return AvObject {
            avtype: AvObjectType::AvEnvironment,
            avclass: 0,
            avhash: 0,
            length: 0,
            values: RefCell::new(Some(results)),
            avstr: None, 
            avbytes: RefCell::new(None), 
            avobjs: RefCell::new(Some(obj_vec))
        };        
    }

    pub fn save_value(&mut self, index: usize, value: u64) {
        let mut values = self.values.borrow_mut();
        if values.is_some() {
            // TODO: Resize?
            values.as_mut().unwrap()[index] = value;
        }
    }

    pub fn get_value(&mut self, index: usize) -> u64 {
        let values = self.values.borrow();
        return values.as_ref().unwrap()[index];
    }
}

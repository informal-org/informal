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
    // AvClass, AvFunction
}

// Matches with the IO object format. The fields present vary based on object type.
pub struct AvObject {
    pub avtype: AvObjectType,
    pub avclass: u32,
    pub avhash: u64,
    pub length: u32,
    pub values: Option<Vec<u64>>,
    pub avstr: Option<String>,     // TOXO: &str vs str vs String
    pub avbytes: Option<Vec<u8>>,
    pub avobjs: Option<Vec<AvObject>>
}
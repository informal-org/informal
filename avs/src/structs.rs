#[derive(Debug,PartialEq)]
pub enum ValueType {
    NoneType, 
    BooleanType,
    NumericType,
    StringType,
	PointerType,
	ErrorType
}
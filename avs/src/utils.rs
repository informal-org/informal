use crate::constants::{VALUE_T_SYM_OBJ, VALUE_T_PTR_OBJ, LOW32_MASK};

// Unwrap pointer
#[inline(always)]
pub fn truncate_symbol(symbol: u64) -> u32 {
    // Clear high nan header & part of payload (assertion - it's unused)
    return (symbol & LOW32_MASK) as u32
} 

#[inline(always)]
pub fn create_value_symbol(raw: u64) -> u64 {
    // Assertion - this was originally the same type.
    // let result = raw | VALUE_T_PTR_OBJ;
    let result = raw | VALUE_T_SYM_OBJ;
    return result;
}

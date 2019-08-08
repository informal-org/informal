use crate::constants::{VALUE_T_SYM_OBJ, VALUE_T_PTR_OBJ, VALUE_T_PTR_STR, LOW32_MASK};

// Unwrap pointer
#[inline(always)]
pub fn truncate_symbol(symbol: u64) -> u32 {
    // Clear high nan header & part of payload (assertion - it's unused)
    return (symbol & LOW32_MASK) as u32
} 

#[inline(always)]
pub fn create_value_symbol(raw: u64) -> u64 {
    // Value type symbols resolve to themselves (no heap lookup needed).
    return raw | VALUE_T_SYM_OBJ;
}

#[inline(always)]
pub fn create_pointer_symbol(raw: u64) -> u64 {
    // Pointer types have a value on the heap. 
    return raw | VALUE_T_PTR_OBJ;
}

#[inline(always)]
pub fn create_string_pointer(raw: u64) -> u64 {
    // TODO: Pointer, length in the future.
    return raw | VALUE_T_PTR_STR;
}


use crate::constants::{VALUE_T_SYM_OBJ, LOW32_MASK};

// Unwrap pointer
#[inline(always)]
pub fn truncate_symbol(symbol: u64) -> u32 {
    // Clear high nan header & part of payload (assertion - it's unused)
    return (symbol & LOW32_MASK) as u32
}

// Repr_pointer
#[inline(always)]
pub fn extend_value_symbol(truncated: u32) -> u64 {
    // Assertion - this was originally a "Value" symbol.
    return (truncated as u64) | VALUE_T_SYM_OBJ;
}
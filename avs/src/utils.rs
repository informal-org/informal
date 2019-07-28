

pub fn truncate_symbol(symbol: u64) -> u32 {
    // Clear high nan header & part of payload (assertion - it's unused)
    let val = symbol & 0x0000_0000_FFFF_FFFF;

    return val as u32
}


pub fn extend_value_symbol(truncated: u32) -> u64 {
    // Assertion - this was originally a "Value" symbol.
    
}
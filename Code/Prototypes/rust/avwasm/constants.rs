/*
// Takes parsed tokens and generates wasm code from it.
// TODO: Convert these to a map lookup
*/
pub const AV_STD_ADD: &'static str  = "(call $__av_add)\n";
pub const AV_STD_SUB: &'static str  = "(call $__av_sub)\n";
pub const AV_STD_MUL: &'static str  = "(call $__av_mul)\n";
pub const AV_STD_DIV: &'static str  = "(call $__av_div)\n";

pub const AV_STD_AND: &'static str  = "(call $__av_and)\n";
pub const AV_STD_OR: &'static str   = "(call $__av_or)\n";
pub const AV_STD_NOT: &'static str   = "(call $__av_not)\n";

pub const AV_STD_LT: &'static str  = "(call $__av_lt)\n";
pub const AV_STD_LTE: &'static str   = "(call $__av_lte)\n";
pub const AV_STD_GT: &'static str   = "(call $__av_gt)\n";
pub const AV_STD_GTE: &'static str   = "(call $__av_gte)\n";

// alternatively. Do .nearest first
pub const WASM_F64_AS_I32: &'static str  = "(i32.trunc_s/f64)\n";
pub const WASM_I32_AS_F64: &'static str  = "(f64.convert_s/i32)\n";
pub const WASM_F64_AS_I64: &'static str = "(i64.reinterpret_f64)\n";

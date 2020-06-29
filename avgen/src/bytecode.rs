/****
 * Web Assembly byte-code format and utilities
 ****/

/**** 
 * Types 
 * https://webassembly.github.io/spec/core/appendix/index-types.html
 * https://webassembly.github.io/spec/core/binary/types.html#function-types
 * ****/
pub const VAL_I32: u8 = 0x7f;
pub const VAL_I64: u8 = 0x7e;
pub const VAL_f32: u8 = 0x7d;
pub const VAL_f64: u8 = 0x7c;
pub const VAL_v128: u8 = 0x7b;

pub const FUNC_TYPE: u8 = 0x60;
pub const RESULT_TYPE: u8 = 0x40;

pub const LIMIT_MIN: u8 = 0x00;
pub const LIMIT_MIN_MAX: u8 = 0x01;

pub const ELEM_FUNCREF: u8 = 0x70;

pub const GLOBAL_CONST: u8 = 0x00;
pub const GLOBAL_VAR: u8 = 0x01;

/***
 * Modules
 * https://webassembly.github.io/spec/core/binary/modules.html
 ***/
pub const MODULE_MAGIC: [u8; 4] = [0x00, 0x61, 0x73, 0x6d];
pub const MODULE_VERSION: [u8; 4] = [0x01, 0x00, 0x00, 0x00];

pub const SECTION_CUSTOM: u8 = 0;
pub const SECTION_TYPE: u8 = 1;
pub const SECTION_IMPORT: u8 = 2;
pub const SECTION_FUNCTION: u8 = 3;
pub const SECTION_TABLE: u8 = 4;
pub const SECTION_MEMORY: u8 = 5;
pub const SECTION_GLOBAL: u8 = 6;
pub const SECTION_EXPORT: u8 = 7;
pub const SECTION_START: u8 = 8;
pub const SECTION_ELEMENT: u8 = 9;
pub const SECTION_CODE: u8 = 10;
pub const SECTION_DATA: u8 = 11;

pub const IMPORT_FUNC: u8 = 0x00;
pub const IMPORT_TABLE: u8 = 0x01;
pub const IMPORT_MEM: u8 = 0x02;
pub const IMPORT_GLOBAL: u8 = 0x03;

pub const EXPORT_FUNC: u8 = 0x00;
pub const EXPORT_TABLE: u8 = 0x01;
pub const EXPORT_MEM: u8 = 0x02;
pub const EXPORT_GLOBAL: u8 = 0x03;


/***
 * Instructions
 * https://webassembly.github.io/spec/core/binary/instructions.html
 * https://webassembly.github.io/spec/core/appendix/index-instructions.html
 ***/
pub const BLOCKTYPE_VOID: u8 = 0x40;    // Other block types are the value type equivalent

pub const OP_UNREACHABLE: u8 = 0x00;
pub const OP_NOP: u8 = 0x01;
pub const OP_BLOCK: u8 = 0x02;
pub const OP_LOOP: u8 = 0x03;
pub const OP_IF: u8 = 0x04;
pub const OP_ELSE: u8 = 0x05;

pub const OP_END: u8 = 0x0B;
pub const OP_BR: u8 = 0x0C;
pub const OP_BR_IF: u8 = 0x0D;
pub const OP_BR_TABLE: u8 = 0x0E;
pub const OP_RETURN: u8 = 0x0F;
pub const OP_CALL: u8 = 0x10;
pub const OP_CALL_INDIRECT: u8 = 0x11;

pub const OP_DROP: u8 = 0x1A;
pub const OP_SELECT: u8 = 0x1B;

pub const OP_LOCAL_GET: u8 = 0x20;
pub const OP_LOCAL_SET: u8 = 0x21;
pub const OP_LOCAL_TEE: u8 = 0x22;
pub const OP_GLOBAL_GET: u8 = 0x23;
pub const OP_GLOBAL_SET: u8 = 0x24;

pub const OP_I32_LOAD: u8 = 0x28;
pub const OP_I64_LOAD: u8 = 0x29;
pub const OP_F32_LOAD: u8 = 0x2A;
pub const OP_F64_LOAD: u8 = 0x2B;

pub const OP_I32_LOAD8_S: u8 = 0x2C;
pub const OP_I32_LOAD8_U: u8 = 0x2D;
pub const OP_I32_LOAD16_S: u8 = 0x2E;
pub const OP_I32_LOAD16_U: u8 = 0x2F;

pub const OP_I64_LOAD8_S: u8 = 0x30;
pub const OP_I64_LOAD8_U: u8 = 0x31;
pub const OP_I64_LOAD16_S: u8 = 0x32;
pub const OP_I64_LOAD16_U: u8 = 0x33;
pub const OP_I64_LOAD32_S: u8 = 0x34;
pub const OP_I64_LOAD32_U: u8 = 0x35;

pub const OP_I32_STORE: u8 = 0x36;
pub const OP_I64_STORE: u8 = 0x37;
pub const OP_F32_STORE: u8 = 0x38;
pub const OP_F64_STORE: u8 = 0x39;

pub const OP_I32_STORE8: u8 = 0x3A;
pub const OP_I32_STORE16: u8 = 0x3B;
pub const OP_I64_STORE8: u8 = 0x3C;
pub const OP_I64_STORE16: u8 = 0x3D;
pub const OP_I64_STORE32: u8 = 0x3E;

pub const OP_MEMORY_SIZE: u8 = 0x3F;
pub const OP_MEMORY_GROW: u8 = 0x40;

pub const OP_I32_CONST: u8 = 0x41;
pub const OP_I64_CONST: u8 = 0x42;
pub const OP_F32_CONST: u8 = 0x43;
pub const OP_F64_CONST: u8 = 0x44;

pub const OP_I32_EQZ: u8 = 0x45;
pub const OP_I32_EQ: u8 = 0x46;
pub const OP_I32_NE: u8 = 0x47;
pub const OP_I32_LT_S: u8 = 0x48;
pub const OP_I32_LT_U: u8 = 0x49;
pub const OP_I32_GT_S: u8 = 0x4A;
pub const OP_I32_GT_U: u8 = 0x4B;
pub const OP_I32_LE_S: u8 = 0x4C;
pub const OP_I32_LE_U: u8 = 0x4D;
pub const OP_I32_GE_S: u8 = 0x4E;
pub const OP_I32_GE_U: u8 = 0x4F;

pub const OP_I64_EQZ: u8 = 0x50;
pub const OP_I64_EQ: u8 = 0x51;
pub const OP_I64_NE: u8 = 0x52;
pub const OP_I64_LT_S: u8 = 0x53;
pub const OP_I64_LT_U: u8 = 0x54;
pub const OP_I64_GT_S: u8 = 0x55;
pub const OP_I64_GT_U: u8 = 0x56;
pub const OP_I64_LE_S: u8 = 0x57;
pub const OP_I64_LE_U: u8 = 0x58;
pub const OP_I64_GE_S: u8 = 0x59;
pub const OP_I64_GE_U: u8 = 0x5A;

pub const OP_F32_EQ: u8 = 0x5B;
pub const OP_F32_NE: u8 = 0x5C;
pub const OP_F32_LT: u8 = 0x5D;
pub const OP_F32_GT: u8 = 0x5E;
pub const OP_F32_LE: u8 = 0x5F;
pub const OP_F32_GE: u8 = 0x60;

pub const OP_F64_EQ: u8 = 0x61;
pub const OP_F64_NE: u8 = 0x62;
pub const OP_F64_LT: u8 = 0x63;
pub const OP_F64_GT: u8 = 0x64;
pub const OP_F64_LE: u8 = 0x65;
pub const OP_F64_GE: u8 = 0x66;

pub const OP_I32_CLZ: u8 = 0x67;
pub const OP_I32_CTZ: u8 = 0x68;
pub const OP_I32_POPCNT: u8 = 0x69;
pub const OP_I32_ADD: u8 = 0x6A;
pub const OP_I32_SUB: u8 = 0x6B;
pub const OP_I32_MUL: u8 = 0x6C;
pub const OP_I32_DIV_S: u8 = 0x6D;
pub const OP_I32_DIV_U: u8 = 0x6E;
pub const OP_I32_REM_S: u8 = 0x6F;
pub const OP_I32_REM_U: u8 = 0x70;
pub const OP_I32_AND: u8 = 0x71;
pub const OP_I32_OR: u8 = 0x72;
pub const OP_I32_XOR: u8 = 0x73;
pub const OP_I32_SHL: u8 = 0x74;
pub const OP_I32_SHR_S: u8 = 0x75;
pub const OP_I32_SHR_U: u8 = 0x76;
pub const OP_I32_ROTL: u8 = 0x77;
pub const OP_I32_ROTR: u8 = 0x78;

pub const OP_I64_CLZ: u8 = 0x79;
pub const OP_I64_CTZ: u8 = 0x7A;
pub const OP_I64_POPCNT: u8 = 0x7B;
pub const OP_I64_ADD: u8 = 0x7C;
pub const OP_I64_SUB: u8 = 0x7D;
pub const OP_I64_MUL: u8 = 0x7E;
pub const OP_I64_DIV_S: u8 = 0x7F;
pub const OP_I64_DIV_U: u8 = 0x80;
pub const OP_I64_REM_S: u8 = 0x81;
pub const OP_I64_REM_U: u8 = 0x82;
pub const OP_I64_AND: u8 = 0x83;
pub const OP_I64_OR: u8 = 0x84;
pub const OP_I64_XOR: u8 = 0x85;
pub const OP_I64_SHL: u8 = 0x86;
pub const OP_I64_SHR_S: u8 = 0x87;
pub const OP_I64_SHR_U: u8 = 0x88;
pub const OP_I64_ROTL: u8 = 0x89;
pub const OP_I64_ROTR: u8 = 0x8A;

pub const OP_F32_ABS: u8 = 0x8B;
pub const OP_F32_NEG: u8 = 0x8C;
pub const OP_F32_CEIL: u8 = 0x8D;
pub const OP_F32_FLOOR: u8 = 0x8E;
pub const OP_F32_TRUNC: u8 = 0x8F;
pub const OP_F32_NEAREST: u8 = 0x90;
pub const OP_F32_SQRT: u8 = 0x91;
pub const OP_F32_ADD: u8 = 0x92;
pub const OP_F32_SUB: u8 = 0x93;
pub const OP_F32_MUL: u8 = 0x94;
pub const OP_F32_DIV: u8 = 0x95;
pub const OP_F32_MIN: u8 = 0x96;
pub const OP_F32_MAX: u8 = 0x97;
pub const OP_F32_COPYSIGN: u8 = 0x98;

pub const OP_F64_ABS: u8 = 0x99;
pub const OP_F64_NEG: u8 = 0x9A;
pub const OP_F64_CEIL: u8 = 0x9B;
pub const OP_F64_FLOOR: u8 = 0x9C;
pub const OP_F64_TRUNC: u8 = 0x9D;
pub const OP_F64_NEAREST: u8 = 0x9E;
pub const OP_F64_SQRT: u8 = 0x9F;
pub const OP_F64_ADD: u8 = 0xA0;
pub const OP_F64_SUB: u8 = 0xA1;
pub const OP_F64_MUL: u8 = 0xA2;
pub const OP_F64_DIV: u8 = 0xA3;
pub const OP_F64_MIN: u8 = 0xA4;
pub const OP_F64_MAX: u8 = 0xA5;
pub const OP_F64_COPYSIGN: u8 = 0xA6;

pub const OP_I32_WRAP_I64: u8 = 0xA7;
pub const OP_I32_TRUNC_F32_S: u8 = 0xA8;
pub const OP_I32_TRUNC_F32_U: u8 = 0xA9;
pub const OP_I32_TRUNC_F64_S: u8 = 0xAA;
pub const OP_I32_TRUNC_F64_U: u8 = 0xAB;

pub const OP_I64_EXTEND_I32_S: u8 = 0xAC;
pub const OP_I64_EXTEND_I32_U: u8 = 0xAD;
pub const OP_I64_TRUNC_F32_S: u8 = 0xAE;
pub const OP_I64_TRUNC_F32_U: u8 = 0xAF;
pub const OP_I64_TRUNC_F64_S: u8 = 0xB0;
pub const OP_I64_TRUNC_F64_U: u8 = 0xB1;

pub const OP_F32_CONVERT_I32_S: u8 = 0xB2;
pub const OP_F32_CONVERT_I32_U: u8 = 0xB3;
pub const OP_F32_CONVERT_I64_S: u8 = 0xB4;
pub const OP_F32_CONVERT_I64_U: u8 = 0xB5;
pub const OP_F32_DEMOTE_F64: u8 = 0xB6;

pub const OP_F64_CONVERT_I32_S: u8 = 0xB7;
pub const OP_F64_CONVERT_I32_U: u8 = 0xB8;
pub const OP_F64_CONVERT_I64_S: u8 = 0xB9;
pub const OP_F64_CONVERT_I64_U: u8 = 0xBA;
pub const OP_F64_PROMOTE_F32: u8 = 0xBB;

pub const OP_I32_REINTERPRET_F32: u8 = 0xBC;
pub const OP_I64_REINTERPRET_F64: u8 = 0xBD;
pub const OP_F32_REINTERPRET_I32: u8 = 0xBE;
pub const OP_F64_REINTERPRET_I64: u8 = 0xBF;

pub const OP_I32_EXTEND8_S: u8 = 0xC0;
pub const OP_I32_EXTEND16_S: u8 = 0xC1;
pub const OP_I64_EXTEND8_S: u8 = 0xC2;
pub const OP_I64_EXTEND16_S: u8 = 0xC3;
pub const OP_I64_EXTEND32_S: u8 = 0xC4;


pub const OP_I32_TRUNC_SAT_F32_S: [u8; 2] = [0xFC, 0x00];
pub const OP_I32_TRUNC_SAT_F32_U: [u8; 2] = [0xFC, 0x01];
pub const OP_I32_TRUNC_SAT_F64_S: [u8; 2] = [0xFC, 0x02];
pub const OP_I32_TRUNC_SAT_F64_U: [u8; 2] = [0xFC, 0x03];

pub const OP_I64_TRUNC_SAT_F32_S: [u8; 2] = [0xFC, 0x04];
pub const OP_I64_TRUNC_SAT_F32_U: [u8; 2] = [0xFC, 0x05];
pub const OP_I64_TRUNC_SAT_F64_S: [u8; 2] = [0xFC, 0x06];
pub const OP_I64_TRUNC_SAT_F64_U: [u8; 2] = [0xFC, 0x07];


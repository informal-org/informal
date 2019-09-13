use crate::constants::*;
use crate::structs::*;

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_nan(f: f64) -> bool {
    // By definition, any comparison with a nan returns 0. 
    // So NaNs can be identified with a self comparison.
    return f != f
}


#[no_mangle]
#[inline(always)]
pub extern "C" fn is_number(value: u64) -> bool {
    // By definition, any comparison with a nan returns 0. 
    // So NaNs can be identified with a self comparison.
    return !is_nan(f64::from_bits(value))
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_truthy(value: u64) -> bool {
    if value & VALHEAD_TRUTHY_MASK == VALHEAD_TRUTHY_MASK {
		// For NaN boxed values, use the truthy bit.
		return true;
	} else {
		// Otherwise, floating point 0, -0, NaN is false, everything else is true
		let f_value: f64 = f64::from_bits(value);
		// TODO: Test case to verify compiler doesn't "optimize" this away
		return f_value > 0.0 || f_value < 0.0;
	}
}


#[no_mangle]
#[inline(always)]
pub extern "C" fn is_object(value: u64) -> bool {
    return (value & VALHEAD_OBJTYPE_MASK) == VALHEAD_OBJTYPE_MASK;
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_string(value: u64) -> bool {
	// Check if NaN bits are set and obj mask bit unset.
	// Objtype mask bit is 0 for empty string, small string or string pointer.
    return (value & SIGNALING_NAN) == SIGNALING_NAN && (value & VALHEAD_OBJTYPE_MASK) != VALHEAD_OBJTYPE_MASK;
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_symbol(value: u64) -> bool {
    return (value & VALHEAD_REFTYPE_MASK) == VALHEAD_REFTYPE_MASK;
}

#[no_mangle]
#[inline(always)]
pub extern "C" fn is_pointer(value: u64) -> bool {
    return (value & SIGNALING_NAN) == SIGNALING_NAN && (value & VALHEAD_REFTYPE_MASK) != VALHEAD_REFTYPE_MASK;
}


#[no_mangle]
#[inline(always)]
pub extern "C" fn is_error(value: u64) -> bool {
	// False pointers = Errors
    return (value & VALHEAD_MASK) == VALUE_F_PTR_OBJ;
}


#[no_mangle]
// Use this only returning type info.
// Use the dedicated is_* function to check type more efficiently.
pub extern "C" fn __av_typeof(value: u64) -> ValueType {
	if (value & SIGNALING_NAN) == SIGNALING_NAN {
		if (value & VALHEAD_OBJTYPE_MASK) != VALHEAD_OBJTYPE_MASK {
			return ValueType::StringType;
		} else {
			let valhead = value & VALHEAD_MASK;
			match valhead {
				VALUE_T_SYM_OBJ => return ValueType::SymbolType,
				VALUE_T_PTR_OBJ => return ValueType::ObjectType, 
				VALUE_F_SYM_OBJ => return ValueType::SymbolType,
				VALUE_F_PTR_OBJ => return ValueType::ObjectType,
				_ => return ValueType::NumericType  // Treat other values as NaN
			}
		}
	} else {
		return ValueType::NumericType
	}
}


#[no_mangle]
pub extern "C" fn __av_as_bool(a: u64) -> bool {
	// TODO: 'bool' fields for objects
	return is_truthy(a);
}

#[inline(always)]
pub extern "C" fn __repr_bool(a: bool) -> u64 {
	if a {
		return SYMBOL_TRUE.symbol
	} 
	else {
		return SYMBOL_FALSE.symbol
	}
}





#[cfg(test)]
mod tests {
	use super::*;

	#[test]
    fn test_as_bool() {
		// Verifies is_truthy as well
		assert_eq!(is_truthy(SYMBOL_TRUE.symbol), true);
		assert_eq!(is_truthy(SYMBOL_FALSE.symbol), false);
		assert_eq!(is_truthy(SYMBOL_NONE.symbol), false);
		assert_eq!(is_truthy(VALUE_ERR), false);
		assert_eq!(is_truthy(f64::to_bits(1.0)), true);
		assert_eq!(is_truthy(f64::to_bits(3.0)), true);
		assert_eq!(is_truthy(f64::to_bits(0.0)), false);
		assert_eq!(is_truthy(f64::to_bits(-0.0)), false);
		// ToDo Nan = false
	}


	#[test]
	fn test_is_object() {
		assert_eq!(is_object(VALUE_F_PTR_OBJ), true);
		assert_eq!(is_object(VALUE_F_SYM_STR), false);
		assert_eq!(is_object(VALUE_F_SYM_OBJ), true);
		assert_eq!(is_object(VALUE_T_PTR_STR), false);
		assert_eq!(is_object(VALUE_T_PTR_OBJ), true);
		assert_eq!(is_object(VALUE_T_SYM_STR), false);
		assert_eq!(is_object(VALUE_T_SYM_OBJ), true);
	}


	#[test]
	fn test_is_string() {
		assert_eq!(is_string(VALUE_F_PTR_OBJ), false);
		assert_eq!(is_string(VALUE_F_SYM_STR), true);
		assert_eq!(is_string(VALUE_F_SYM_OBJ), false);
		assert_eq!(is_string(VALUE_T_PTR_STR), true);
		assert_eq!(is_string(VALUE_T_PTR_OBJ), false);
		assert_eq!(is_string(VALUE_T_SYM_STR), true);
		assert_eq!(is_string(VALUE_T_SYM_OBJ), false);
	}


	#[test]
	fn test_is_symbol() {
		assert_eq!(is_symbol(VALUE_F_PTR_OBJ), false);
		assert_eq!(is_symbol(VALUE_F_SYM_STR), true);
		assert_eq!(is_symbol(VALUE_F_SYM_OBJ), true);
		assert_eq!(is_symbol(VALUE_T_PTR_STR), false);
		assert_eq!(is_symbol(VALUE_T_PTR_OBJ), false);
		assert_eq!(is_symbol(VALUE_T_SYM_STR), true);
		assert_eq!(is_symbol(VALUE_T_SYM_OBJ), true);
	}


	#[test]
	fn test_is_pointer() {
		assert_eq!(is_pointer(VALUE_F_PTR_OBJ), true);
		assert_eq!(is_pointer(VALUE_F_SYM_STR), false);
		assert_eq!(is_pointer(VALUE_F_SYM_OBJ), false);
		assert_eq!(is_pointer(VALUE_T_PTR_STR), true);
		assert_eq!(is_pointer(VALUE_T_PTR_OBJ), true);
		assert_eq!(is_pointer(VALUE_T_SYM_STR), false);
		assert_eq!(is_pointer(VALUE_T_SYM_OBJ), false);
	}


	#[test]
	fn test_is_error() {
		assert_eq!(is_error(VALUE_F_PTR_OBJ), true);
		assert_eq!(is_error(VALUE_F_SYM_STR), false);
		assert_eq!(is_error(VALUE_F_SYM_OBJ), false);
		assert_eq!(is_error(VALUE_T_PTR_STR), false);
		assert_eq!(is_error(VALUE_T_PTR_OBJ), false);
		assert_eq!(is_error(VALUE_T_SYM_STR), false);
		assert_eq!(is_error(VALUE_T_SYM_OBJ), false);
	}	


}
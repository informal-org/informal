#[macro_export]
macro_rules! validate_type {
	($v:expr, $t:expr) => ({
		if __av_typeof($v) != $t {
			return RUNTIME_ERR_INVALID_TYPE;
		}
	})
}

#[macro_export]
macro_rules! disallow_nan {
	($f_a:expr, $f_b: expr) => {
		if $f_a != $f_a || $f_b != $f_b {
			return RUNTIME_ERR_TYPE_NAN;
		}
	}
}

#[macro_export]
macro_rules! valid_num {
	($val:expr) => ({
		if __av_typeof($val) != ValueType::NumericType {
			return RUNTIME_ERR_EXPECTED_NUM
		}
		let f_val = f64::from_bits($val);
		// Disallow nan
		if f_val != f_val {
			return RUNTIME_ERR_TYPE_NAN
		}
		f_val
	})
}

#[macro_export]
macro_rules! resolve_atom {
	($env:expr, $val:expr) => ({
		// Given a u64, return the f64 resolved value or raise error
		if is_number($val) {
			let f_val = f64::from_bits($val);
			if f_val != f_val {
				return RUNTIME_ERR_TYPE_NAN
			}
			Atom::NumericValue(f_val)
		} else if is_symbol($val) {
			// TODO: Resolve rather than get to follow symbols?
			let symbol_resolution = $env.get_atom($val);
			if symbol_resolution.is_some() {
				symbol_resolution.unwrap().clone()
			} else {
				Atom::SymbolValue($val)
			}
		} else {
			// Should not happen
			return RUNTIME_ERR_EXPECTED_NUM
		}
	})
}


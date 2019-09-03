

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
		let f_val = f64::from_bits($val);
		// Disallow nan or other data types
		if is_nan(f_val) {
			return RUNTIME_ERR_EXPECTED_NUM
		}
		f_val
	})
}

#[macro_export]
macro_rules! resolve_atom {
	($env:expr, $val:expr) => ({
		let f_val = f64::from_bits($val);
		// Given a u64, return the f64 resolved value or raise error
		if !is_nan(f_val) {
			Atom::NumericValue(f_val)
		} else if is_pointer($val) {
			let symbol_resolution = $env.resolve_symbol($val);
			println!("Resolved symbol {:X} -> {:?}", $val, symbol_resolution);
			if symbol_resolution.is_some() {
				symbol_resolution.unwrap().clone()
			} else {
				Atom::SymbolValue($val)
			}
		} else {
			println!("is symbol false");
			// Encountered other NaN Type
			return RUNTIME_ERR_EXPECTED_NUM
		}
	})
}


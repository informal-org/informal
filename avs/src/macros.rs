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


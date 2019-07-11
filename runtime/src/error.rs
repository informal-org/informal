use std::result;

use avs::error::ArevelError;

pub type Result<T> = result::Result<T, ArevelError>;
const std = @import("std");

// The build options are primarily configured through build.zig.
// This file provides fallback defaults for `zig test` invocations that don't go through `build.zig`.
// When building via `zig build`, these are replaced by the generated options module.

pub const log_level: std.log.Level = .debug;
pub const benchmark: bool = false;

pub const debug: bool = true;
pub const disable_zig_lazy: bool = false;

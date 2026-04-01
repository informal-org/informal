// Root test entry point that imports all test modules.
// Run with: zig build test

comptime {
    _ = @import("test/test_arm.zig");
    _ = @import("test/test_lexer.zig");
    _ = @import("test/test_parser.zig");
    _ = @import("test/test_resolution.zig");
    _ = @import("test/test_token.zig");
    _ = @import("filetest.zig");
}

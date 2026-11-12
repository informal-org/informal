// Root test entry point that imports all test modules.
// Run with: zig build test
// block and depmap tests disabled until we re-enable IR

comptime {
    _ = @import("test/test_arm.zig");
    _ = @import("test/test_lexer.zig");
    _ = @import("test/test_token.zig");
    _ = @import("filetest.zig");
    _ = @import("test/test_termite.zig");
}

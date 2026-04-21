const std = @import("std");
const parser = @import("../parser.zig");
const tok = @import("../token.zig");
const Token = tok.Token;
const TK = tok.Kind;
const rs = @import("../resolution.zig");
const Resolution = rs.Resolution;
const Scope = rs.Scope;
const UNDECLARED_SENTINEL = rs.UNDECLARED_SENTINEL;

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;

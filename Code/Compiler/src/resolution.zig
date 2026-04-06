/////////////////////////////////////////////
// Symbol Resolution
// The lexer normalizes string symbols to a numeric index.
// But not all who go by the same name are the same thing.
// The parser is responsible for contexualizing the symbol in terms of declaration vs reference per scope.
// We can do symbol-resolution without a second pass with some bookkeeping.
// As you encounter symbols, maintain a stack of declarations.
// It's straightforward to match up references to those declarations, and create an SSA-like indexed versions for assignments.
// The tricky part is forward references. When you encounter a reference to an as-yet undefined symbol,
// add its token location to a list of undefined refs at that symbol and leave a blank spot for it in the parsed queue.
// When you encounter a declaration, check which of those are "within scope" by looking at the current active scope's start index
// If token index > start index (and we know it's less than end index by iteration order)
// AND if current scope is one that supports forward declarations (objects, global support it. A function / condition block doens't).
/////////////////////////////////////////////

const std = @import("std");
const print = std.debug.print;
const parser = @import("parser.zig");
const tok = @import("token.zig");
const Token = tok.Token;

const ScopeType = enum {
    base,
    module,
    object,
    function,
    block,
};

pub const Scope = struct {
    start: u32,
    // We could look this up in the parser queue by start index, but given how frequently we have to look it up as part of resolution
    // it's beneficial to keep it easily available.
    scopeType: ScopeType,
    // There is some wasted space here for padding... We could truncate start if we want to keep this under 4 bytes.
};

// Zero index is assumed to always be some root node in the parser, not a declaration
pub const UNDECLARED_SENTINEL = 0;

pub fn calcOffset(comptime T: anytype, target: u32, index: u32) T {
    const signedTarget: i32 = @intCast(target);
    const signedIndex: i32 = @intCast(index);
    const offset: u32 = @bitCast(signedTarget - signedIndex);
    return @truncate(offset);
}

pub fn applyOffset(comptime signedOffsetT: anytype, index: u32, offset: anytype) u32 {
    const signedIndex: i32 = @intCast(index);
    const signedOffset: signedOffsetT = @bitCast(offset); // i16
    return @bitCast(signedIndex + signedOffset); // Assert - this should always be positive.
}

pub const Resolution = struct {
    // declarations[] is a u64 array packed as:
    //   bits 63:56  fn_depth (u8)    — function depth when this declaration was made
    //   bits 55:32  chain_tail (u24) — parsedQ index of last reference in forward chain (0 = none)
    //   bits 31:0   decl_index (u32) — parsedQ index of most recent declaration (0 = UNDECLARED)

    const Self = @This();
    allocator: std.mem.Allocator,

    // Map from a symbol ID -> packed u64 entry for that symbol's declaration state.
    declarations: []u64,

    // Symbol ID -> tail of the last unresolved reference for each general symbol name.
    unresolved: []u32,

    // Start index of the each scope and its scope type.
    scopeStack: std.array_list.AlignedManaged(Scope, null),
    scopeId: u16,

    // Tracks how many function scopes are currently open. Block scopes don't affect it.
    current_fn_depth: u8,

    parsedQ: *parser.TokenQueue,

    // --- Pack/unpack helpers for declarations[] entries ---

    pub fn getDeclIndex(entry: u64) u32 {
        return @truncate(entry);
    }

    pub fn getChainTail(entry: u64) u32 {
        return @as(u32, @truncate(entry >> 32)) & 0xFFFFFF;
    }

    pub fn getFnDepth(entry: u64) u8 {
        return @truncate(entry >> 56);
    }

    fn packEntry(decl_index: u32, chain_tail: u32, fn_depth: u8) u64 {
        return (@as(u64, fn_depth) << 56) | (@as(u64, chain_tail & 0xFFFFFF) << 32) | @as(u64, decl_index);
    }

    pub fn init(allocator: std.mem.Allocator, maxSymbols: u32, parsedQ: *parser.TokenQueue) !Self {
        const declarations = try allocator.alloc(u64, maxSymbols);
        @memset(declarations, 0); // 0 = undeclared (decl_index=0, chain_tail=0, fn_depth=0)

        const unresolved = try allocator.alloc(u32, maxSymbols);
        @memset(unresolved, UNDECLARED_SENTINEL);

        var scopeStack = std.array_list.AlignedManaged(Scope, null).init(allocator);
        // Initialize with a base module scope.
        try scopeStack.append(Scope{ .start = 0, .scopeType = .base });

        return Self{
            .allocator = allocator,
            .declarations = declarations,
            .unresolved = unresolved,
            .scopeStack = scopeStack,
            .parsedQ = parsedQ,
            .scopeId = 0,
            .current_fn_depth = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.declarations);
        self.allocator.free(self.unresolved);
        self.scopeStack.deinit();
    }

    pub fn startScope(
        self: *Self,
        scope: Scope,
    ) !void {
        try self.scopeStack.append(scope);
        self.scopeId += 1;
        if (scope.scopeType == .function) {
            self.current_fn_depth += 1;
            std.debug.assert(self.current_fn_depth < 255); // Safety valve for u8 overflow
        }
    }

    pub fn endScope(self: *Self, index: u32) !void {
        const scope = self.scopeStack.pop() orelse return;

        if (scope.scopeType == .function) {
            self.current_fn_depth -= 1;
            // No cleanup — stale entries detected lazily by resolve().
        }

        // Patch start token to point to end — only for grp_indent scope markers.
        const startNode = self.parsedQ.list.items[scope.start];
        if (startNode.kind == tok.Kind.grp_indent) {
            self.parsedQ.list.items[scope.start] = tok.Token.lex(startNode.kind, index, startNode.data.value.arg1);
        }
    }

    fn getCurrentScope(self: *Self) Scope {
        // The scope stack is always non-empty since we initialize with a base module scope
        return self.scopeStack.items[self.scopeStack.items.len - 1];
    }

    pub fn declare(
        self: *Self,
        index: u32,
        token: tok.Token,
    ) tok.Token {
        const sym_id = token.data.value.arg0;
        std.debug.assert(sym_id < (1 << 24)); // symbolId must fit in 24 bits
        const result = self.chainTokenDeclaration(index, token);

        // Pack fn_depth into upper 8 bits of arg0, symbolId in lower 24.
        const packed_arg0 = (@as(u32, self.current_fn_depth) << 24) | (sym_id & 0xFFFFFF);
        const final_result = tok.Token{
            .kind = result.kind,
            .data = .{ .value = .{ .arg0 = packed_arg0, .arg1 = result.data.value.arg1 } },
            .aux = result.aux,
        };

        // Update declarations[]: this is the new decl, no references yet.
        self.declarations[sym_id] = packEntry(index, 0, self.current_fn_depth);

        std.log.debug("Declared [{any}] at {any} depth={d}", .{ token, index, self.current_fn_depth });

        // Resolve any previously unresolved refs for this given symbol.
        self.resolveForwardDeclarations(index, sym_id);
        return final_result;
    }

    fn chainTokenDeclaration(self: *Self, index: u32, token: tok.Token) tok.Token {
        // Internal helper to add a new declaration for a given symbol
        const symbol = token.data.value.arg0;
        const entry = self.declarations[symbol];
        const prevDeclIdx = getDeclIndex(entry);
        // Index - Current parser index where this variable is being declared.
        // Symbol - Normalized Symbol ID for the variable name.
        if (prevDeclIdx == UNDECLARED_SENTINEL) {
            // First seen declaration for this symbol.
            return token.newDeclaration(UNDECLARED_SENTINEL);
        } else {
            // Declare this as the latest declaration, and chain a reference to the previous declaration.
            const offset = calcOffset(u16, prevDeclIdx, index); // Negative offset, since index is always greater than prev.
            return token.newDeclaration(@truncate(offset));
        }
    }

    fn resolveForwardDeclarations(self: *Self, declarationIndex: u32, sym_id: u32) void {
        // Check if the current scope type supports forward-declaration where the usage can come before the declaration.
        const currentScope = self.getCurrentScope();
        if (currentScope.scopeType == .module or currentScope.scopeType == .object) {
            var unresolvedRefIdx = self.unresolved[sym_id];

            while (unresolvedRefIdx != UNDECLARED_SENTINEL) {

                // This reference is within this current scope (or one of its child scopes - which can still access this forward ref)
                if (unresolvedRefIdx >= currentScope.start) {
                    const ref = self.parsedQ.list.items[unresolvedRefIdx];
                    const offset = calcOffset(u16, declarationIndex, unresolvedRefIdx); // Should be positive, since this is a forward ref.
                    // TODO: Overflow checks.

                    // Resolve this symbol ref in the parsed queue to this current declaration.
                    self.parsedQ.list.items[unresolvedRefIdx] = tok.Token{
                        .kind = ref.kind,
                        .data = .{ .value = .{ .arg0 = ref.data.value.arg0, .arg1 = @truncate(offset) } },
                        .aux = ref.aux,
                    };

                    // Update pointer to the next unresolved ref in the chain.
                    if (ref.data.value.arg1 == UNDECLARED_SENTINEL) {
                        unresolvedRefIdx = ref.data.value.arg1;
                        break;
                    } else {
                        // Assume - arg1 offset is going to be negative here.
                        unresolvedRefIdx = applyOffset(i16, unresolvedRefIdx, ref.data.value.arg1);
                    }
                } else {
                    // This and any priors can't see this current declaration, since it's out of scope.
                    break;
                }
            }
            // Set the ref to the last unresolved ref. Everything else has been resolved.
            self.unresolved[sym_id] = unresolvedRefIdx;
        }
    }

    pub fn resolve(self: *Self, index: u32, token: tok.Token) tok.Token {
        const sym_id = token.data.value.arg0;
        const entry = self.declarations[sym_id];
        const decl_idx = getDeclIndex(entry);

        if (decl_idx == UNDECLARED_SENTINEL) {
            // No declarations found, add to unresolved list.
            self.unresolved[sym_id] = index;
            std.log.debug("Resolved [{any}] unresolved", .{token});
            return tok.Token{
                .kind = token.kind,
                .data = .{ .value = .{ .arg0 = sym_id, .arg1 = UNDECLARED_SENTINEL } },
                .aux = token.aux,
            };
        }

        // Staleness check: if the declaration was made at a deeper fn_depth than current,
        // it belongs to a function scope that has since closed.
        if (getFnDepth(entry) > self.current_fn_depth) {
            return self.resolveStale(index, token, sym_id, entry);
        }

        // Normal resolution
        const offset = calcOffset(u16, decl_idx, index);

        // Forward chain: patch previous tail's arg0 to point to this reference.
        const tail = getChainTail(entry);
        if (tail != 0) {
            const prev = self.parsedQ.list.items[tail];
            self.parsedQ.list.items[tail] = tok.Token{
                .kind = prev.kind,
                .data = .{ .value = .{ .arg0 = index, .arg1 = prev.data.value.arg1 } },
                .aux = prev.aux,
            };
        }

        // Advance chain tail, preserve decl_index and fn_depth.
        self.declarations[sym_id] = packEntry(decl_idx, index, getFnDepth(entry));

        const signedOffset: i16 = @bitCast(offset);
        std.log.debug("Resolved [{any}] to offset {any}", .{ token, signedOffset });

        // arg0=0 means no next use yet. arg1=offset to declaration.
        return tok.Token{
            .kind = token.kind,
            .data = .{ .value = .{ .arg0 = 0, .arg1 = offset } },
            .aux = token.aux,
        };
    }

    fn resolveStale(self: *Self, index: u32, token: tok.Token, sym_id: u32, stale_entry: u64) tok.Token {
        // Cold path: walk the declaration chain backward to find a valid (non-stale) declaration.
        // Each declaration's arg0 has fn_depth in upper 8 bits. We look for fn_depth <= current_fn_depth.
        var decl_idx = getDeclIndex(stale_entry);

        while (true) {
            const decl_token = self.parsedQ.list.items[decl_idx];
            const prev_offset = decl_token.data.value.arg1;

            if (prev_offset == UNDECLARED_SENTINEL) {
                // Hit the end of the chain — no valid declaration in scope.
                self.declarations[sym_id] = 0; // mark undeclared
                std.log.debug("resolveStale: no valid decl for sym {d}", .{sym_id});
                return tok.Token{
                    .kind = token.kind,
                    .data = .{ .value = .{ .arg0 = sym_id, .arg1 = UNDECLARED_SENTINEL } },
                    .aux = token.aux,
                };
            }

            decl_idx = applyOffset(i16, decl_idx, prev_offset);
            const prev_arg0 = self.parsedQ.list.items[decl_idx].data.value.arg0;
            const prev_fn_depth: u8 = @truncate(prev_arg0 >> 24);

            if (prev_fn_depth <= self.current_fn_depth) {
                // Found valid declaration — resolve against it.
                const offset = calcOffset(u16, decl_idx, index);

                // Lazy cleanup: update declarations[] so future lookups are clean.
                self.declarations[sym_id] = packEntry(decl_idx, index, prev_fn_depth);

                const signedOffset: i16 = @bitCast(offset);
                std.log.debug("resolveStale: found valid decl at {d} depth={d} offset={any}", .{ decl_idx, prev_fn_depth, signedOffset });

                // Start a new forward chain segment from this reference.
                return tok.Token{
                    .kind = token.kind,
                    .data = .{ .value = .{ .arg0 = 0, .arg1 = offset } },
                    .aux = token.aux,
                };
            }
            // Still stale — keep walking.
        }
    }
};

test {
    _ = @import("test/test_resolution.zig");
}

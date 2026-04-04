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
    // Optimization thoughts:
    // We're currently using fixed sized arrays, which will grow by the number of defined names.
    // The alternative is a a hash-map, which compromises some lookup/bookkeeping performance for space
    // But with more aggressive cleanup of names that go out of scope to reuse their space.
    // This current version avoids that extra overhead and likely the better option, as long as we keep it scoped to a single file.

    // Conventions:
    // All token offsets are signed relative to the current index.
    // So current index + offset = target i.e. offset = target - index.
    // So negative offset references some previous value, positive references a future/forward ref.

    const Self = @This();
    allocator: std.mem.Allocator,

    // Map from a symbol ID -> the tail of a declaration linked-list for that generic name.
    // Each declaration points to the previous declaration, higher up the scope chain.
    declarations: []u32,

    // Symbol ID -> tail of the last unresolved reference for each general symbol name.
    unresolved: []u32,

    // Start index of the each scope and its scope type.
    scopeStack: std.array_list.AlignedManaged(Scope, null),
    scopeId: u16,

    parsedQ: *parser.TokenQueue,

    pub fn init(allocator: std.mem.Allocator, maxSymbols: u32, parsedQ: *parser.TokenQueue) !Self {
        const declarations = try allocator.alloc(u32, maxSymbols);
        @memset(declarations, UNDECLARED_SENTINEL);

        const unresolved = try allocator.alloc(u32, maxSymbols);
        @memset(unresolved, UNDECLARED_SENTINEL);

        var scopeStack = std.array_list.AlignedManaged(Scope, null).init(allocator);
        // Initialize with a base module scope.
        try scopeStack.append(Scope{ .start = 0, .scopeType = .base });

        return Self{ .allocator = allocator, .declarations = declarations, .unresolved = unresolved, .scopeStack = scopeStack, .parsedQ = parsedQ, .scopeId = 0 };
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
    }

    pub fn endScope(self: *Self, index: u32) !void {
        const scope = self.scopeStack.pop() orelse return;

        // Restore declarations for function scopes so parameters don't leak into outer scope.
        // TODO: There should be a more efficient way of doing this without full iteration.
        if (scope.scopeType == .function) {
            var i: u32 = scope.start;
            while (i < index) : (i += 1) {
                const token = self.parsedQ.list.items[i];
                if (token.aux.declaration) {
                    const symbolId = token.data.value.arg0;
                    const prevDeclOffset = token.data.value.arg1;
                    if (prevDeclOffset == UNDECLARED_SENTINEL) {
                        self.declarations[symbolId] = UNDECLARED_SENTINEL;
                    } else {
                        self.declarations[symbolId] = applyOffset(i16, i, prevDeclOffset);
                    }
                }
            }
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
        const result = self.chainTokenDeclaration(index, token);
        self.declarations[token.data.value.arg0] = index;
        std.log.debug("Declared [{any}] at {any}", .{ token, index });

        // Resolve any previously unresolved refs for this given symbol.
        self.resolveForwardDeclarations(index, result);
        return result;
    }

    fn chainTokenDeclaration(self: *Self, index: u32, token: tok.Token) tok.Token {
        // Internal helper to add a new declaration for a given symbol
        const symbol = token.data.value.arg0;
        const prevDeclaration = self.declarations[symbol];
        // Index - Current parser index where this variable is being declared.
        // Symbol - Normalized Symbol ID for the variable name.
        if (prevDeclaration == UNDECLARED_SENTINEL) {
            // First seen declaration for this symbol.
            // We could give it an SSA ID here if we wanted.
            // First is the some combo of symbol + 0, second dec looks up previous ID + 1.
            return token.newDeclaration(UNDECLARED_SENTINEL);
        } else {
            // Declare this as the latest declaration, and chain a reference to the previous declaration.x
            const offset = calcOffset(u16, prevDeclaration, index); // Negative offset, since index is always greater than prev.
            return token.newDeclaration(@truncate(offset));
        }
    }

    fn resolveForwardDeclarations(self: *Self, declarationIndex: u32, token: tok.Token) void {
        // Check if the current scope type supports forward-declaration where the usage can come before the declaration.
        const currentScope = self.getCurrentScope();
        if (currentScope.scopeType == .module or currentScope.scopeType == .object) {
            const symbol = token.data.value.arg0;
            var unresolvedRefIdx = self.unresolved[symbol];

            while (unresolvedRefIdx != UNDECLARED_SENTINEL) {

                // This reference is within this current scope (or one of its child scopes - which can still access this forward ref)
                if (unresolvedRefIdx >= currentScope.start) {
                    const ref = self.parsedQ.list.items[unresolvedRefIdx];
                    const offset = calcOffset(u16, declarationIndex, unresolvedRefIdx); // Should be positive, since this is a forward ref.
                    // TODO: Overflow checks.

                    // Resolve this symbol ref in the parsed queue to this current declaration.
                    self.parsedQ.list.items[unresolvedRefIdx] = tok.Token{
                        .kind = ref.kind,
                        .data = .{ .value = .{ .arg0 = symbol, .arg1 = @truncate(offset) } },
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
            self.unresolved[symbol] = unresolvedRefIdx;
        }
    }

    pub fn resolve(self: *Self, index: u32, token: tok.Token) tok.Token {
        // Resolve a symbol to a declaration, or add it to the unresolved list if no declarations are found.
        // If there are previous unresolved refs, set this symbol's offset to that in the parsed queue.
        const symbol = token.data.value.arg0;
        // Offset should be negative if there's an existing declaration.
        const offset = if (self.declarations[symbol] != UNDECLARED_SENTINEL) calcOffset(u16, self.declarations[symbol], index) else UNDECLARED_SENTINEL;
        if (self.declarations[symbol] == UNDECLARED_SENTINEL) {
            // No declarations found, add to unresolved list.
            // TODO: Reviewing this code again, Do I need a linked-list structure for this too?
            // TODO TODO TODO
            self.unresolved[symbol] = index;
        }
        const signedOffset: i16 = @bitCast(offset);
        std.log.debug("Resolved [{any}] to offset {any}", .{ token, signedOffset });
        return tok.Token{
            .kind = token.kind,
            .data = .{ .value = .{ .arg0 = symbol, .arg1 = offset } },
            .aux = token.aux,
        };
    }
};

test {
    _ = @import("test/test_resolution.zig");
}

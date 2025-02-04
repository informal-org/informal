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

const DEBUG = true;

const ScopeType = enum {
    base,
    module,
    object,
    function,
    block,
};

const Scope = struct {
    start: u32,
    // We could look this up in the parser queue by start index, but given how frequently we have to look it up as part of resolution
    // it's beneficial to keep it easily available.
    scopeType: ScopeType,
    // There is some wasted space here for padding... We could truncate start if we want to keep this under 4 bytes.
};

// Zero index is assumed to always be some root node in the parser, not a declaration
const UNDECLARED_SENTINEL = 0;

pub fn calcOffset(target: u32, index: u32) u16 {
    const signedTarget: i32 = @intCast(target);
    const signedIndex: i32 = @intCast(index);
    const offset: u32 = @bitCast(signedTarget - signedIndex);
    return @truncate(offset);
}

pub fn applyOffset(index: u32, offset: u16) u32 {
    const signedIndex: i32 = @intCast(index);
    const signedOffset: i16 = @bitCast(offset);
    return @bitCast(signedIndex + signedOffset); // Assert - this should always be positive.
}

pub const Namespace = struct {
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
    scopeStack: std.ArrayList(Scope),

    parsedQ: *parser.TokenQueue,

    pub fn init(allocator: std.mem.Allocator, maxSymbols: u32, parsedQ: *parser.TokenQueue) !Self {
        const declarations = try allocator.alloc(u32, maxSymbols);
        @memset(declarations, UNDECLARED_SENTINEL);

        const unresolved = try allocator.alloc(u32, maxSymbols);
        @memset(unresolved, UNDECLARED_SENTINEL);

        var scopeStack = std.ArrayList(Scope).init(allocator);
        // Initialize with a base module scope.
        try scopeStack.append(Scope{ .start = 0, .scopeType = .base });

        return Self{ .allocator = allocator, .declarations = declarations, .unresolved = unresolved, .scopeStack = scopeStack, .parsedQ = parsedQ };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.declarations);
        self.allocator.free(self.unresolved);
        self.scopeStack.deinit();
    }

    fn chainTokenDeclaration(self: *Self, index: u32, token: tok.Token) tok.Token {
        // Internal helper to add a new declaration for a given symbol
        if (DEBUG) {
            print("Declaring token: {any} at index {d}\n", .{ token, index });
        }
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
            const offset = calcOffset(prevDeclaration, index); // Negative offset, since index is always greater than prev.
            return token.newDeclaration(@truncate(offset));
        }
    }

    fn getCurrentScope(self: *Self) Scope {
        // The scope stack is always non-empty since we initialize with a base module scope
        return self.scopeStack.items[self.scopeStack.items.len - 1];
    }

    fn forwardDeclare(self: *Self, declarationIndex: u32, token: tok.Token) void {
        // Check if the current scope type supports forward-declaration where the usage can come before the declaration.
        const currentScope = self.getCurrentScope();
        if (currentScope.scopeType == .module or currentScope.scopeType == .object) {
            const symbol = token.data.value.arg0;
            var unresolvedRefIdx = self.unresolved[symbol];

            while (unresolvedRefIdx != UNDECLARED_SENTINEL) {

                // This reference is within this current scope (or one of its child scopes - which can still access this forward ref)
                if (unresolvedRefIdx >= currentScope.start) {
                    const ref = self.parsedQ.list.items[unresolvedRefIdx];
                    const offset = calcOffset(declarationIndex, unresolvedRefIdx); // Should be positive, since this is a forward ref.
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
                        unresolvedRefIdx = applyOffset(unresolvedRefIdx, ref.data.value.arg1);
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

    pub fn declare(
        self: *Self,
        index: u32,
        token: tok.Token,
    ) tok.Token {
        const result = self.chainTokenDeclaration(index, token);
        self.declarations[token.data.value.arg0] = index;
        // Resolve any previously unresolved refs for this given symbol.
        self.forwardDeclare(index, result);
        return result;
    }

    pub fn resolve(self: *Self, index: u32, token: tok.Token) tok.Token {
        // Resolve a symbol to a declaration, or add it to the unresolved list if no declarations are found.
        // If there are previous unresolved refs, set this symbol's offset to that in the parsed queue.
        const symbol = token.data.value.arg0;
        // Offset should be negative if there's an existing declaration.
        const offset = if (self.declarations[symbol] != UNDECLARED_SENTINEL) calcOffset(self.declarations[symbol], index) else UNDECLARED_SENTINEL;
        if (self.declarations[symbol] == UNDECLARED_SENTINEL) {
            // No declarations found, add to unresolved list.
            self.unresolved[symbol] = index;
        }
        if (DEBUG) {
            print("Resolved {any} to {any} at offset {any}\n", .{ token, self.declarations[symbol], offset });
        }
        return tok.Token{
            .kind = token.kind,
            .data = .{ .value = .{ .arg0 = symbol, .arg1 = offset } },
            .aux = token.aux,
        };
    }

    pub fn startScope(
        self: *Self,
        scope: Scope,
    ) !void {
        try self.scopeStack.append(scope);
    }

    pub fn endScope(self: *Self) !void {
        _ = self.scopeStack.pop();
    }
};

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const TK = tok.TK;

// Situations:
// Same scope:
// declaration
// reference
test "Normal declaration and reference" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var namespace = try Namespace.init(test_allocator, 3, &parsedQ);
    defer namespace.deinit();

    // hello = 42
    try parsedQ.push(Token.lex(TK.lit_number, 0, 1));
    try parsedQ.push(Token.lex(TK.identifier, 0, 5)); // Symbol ID 0 with len of 5
    try parsedQ.push(Token.lex(TK.lit_number, 42, 2));
    try parsedQ.push(Token.lex(TK.op_assign_eq, 0, 1));
    // Reference hello
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));

    const decResult = namespace.declare(1, parsedQ.list.items[1]);
    try expectEqual(0, decResult.data.value.arg0);
    try expectEqual(UNDECLARED_SENTINEL, decResult.data.value.arg1); // Nothing was defined before this.

    const refResult = namespace.resolve(4, parsedQ.list.items[4]);
    const refOffset: i16 = @bitCast(refResult.data.value.arg1);
    try expectEqual(1 - 4, refOffset); // offset = declaration index - ref index.
    try expectEqual(0, refResult.data.value.arg0);
}

// Sub-scope can reference previous
// declaration
//    reference

// Scope can reference previous declarations which come after if it the scope supports forward-declarations.
// reference
// module-level declaration (Supports forward-declarations)

// Sub-scope can reference forward-declarations if the defining scope supports it.
// ...
//    function sub-scope without forward-declarations
//        reference
// module-level declaration (supports forward declaration)
test "Forward reference from child scope" {
    var parsedQ = parser.TokenQueue.init(test_allocator);
    defer parsedQ.deinit();
    var namespace = try Namespace.init(test_allocator, 3, &parsedQ);
    defer namespace.deinit();

    // hello = 42
    try namespace.startScope(Scope{ .start = 1, .scopeType = .module });
    try parsedQ.push(Token.lex(TK.lit_number, 0, 1));
    try parsedQ.push(Token.lex(TK.grp_indent, 0, 0)); // Start of some new scope
    try namespace.startScope(Scope{ .start = 1, .scopeType = .function });

    try parsedQ.push(Token.lex(TK.identifier, 0, 5)); // Reference to some unknown identifier.
    const refResult = namespace.resolve(2, parsedQ.list.items[2]);
    parsedQ.list.items[2] = refResult;
    // Expect it to be unresolved.
    try expectEqual(UNDECLARED_SENTINEL, refResult.data.value.arg1);
    try expectEqual(2, namespace.unresolved[0]);

    // Say some reference is defined after it (shadowing).
    // The name shouldn't resolve since func scope doesn't support forward ref.
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));
    try parsedQ.push(Token.lex(TK.lit_number, 99, 2));
    try parsedQ.push(Token.lex(TK.op_assign_eq, 0, 1));

    // Expect it to not be have a definition before.
    try expectEqual(UNDECLARED_SENTINEL, namespace.declarations[0]);
    const shadowDefResult = namespace.declare(3, parsedQ.list.items[3]);
    parsedQ.list.items[3] = shadowDefResult;
    try expectEqual(UNDECLARED_SENTINEL, shadowDefResult.data.value.arg1);
    try expectEqual(3, namespace.declarations[0]);
    // Expect not to resolve the unresolbed ref since this is a shadowing post-def without forward semantics.
    try expectEqual(2, namespace.unresolved[0]);

    // End function scope and declare the ref at the base module scope. Expect it to resolve.
    try parsedQ.push(Token.lex(TK.grp_dedent, 0, 0));
    try namespace.endScope();
    try parsedQ.push(Token.lex(TK.identifier, 0, 5));

    try expectEqual(UNDECLARED_SENTINEL, parsedQ.list.items[2].data.value.arg1);
    const baseDefResult = namespace.declare(5, parsedQ.list.items[5]);
    parsedQ.list.items[5] = baseDefResult;
    try expectEqual(5, namespace.declarations[0]);
    const baseDefOffset: i16 = @bitCast(baseDefResult.data.value.arg1);
    try expectEqual(3 - 5, baseDefOffset); // Reference the shadow declaration.
    // Expect it to be resolved now.
    try expectEqual(UNDECLARED_SENTINEL, namespace.unresolved[0]);
    const afterOffset: i16 = @bitCast(parsedQ.list.items[2].data.value.arg1);
    try expectEqual(5 - 2, afterOffset); // Declared at 5 - ref at 2
    // Expect the parsed queue to have been updated as well.
}

// Unsupported forward-declarations remain unresolved. We may want to throw a shadowing warning?
// function scope without forward-declarations
//    reference (should remain unresolved)
//    some other sub-scope with forward-declarations
//        reference (should remain unresolved)
//    declaration
//

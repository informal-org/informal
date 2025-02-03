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

const Namespace = struct {
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

    pub fn init(allocator: std.mem.Allocator, maxSymbols: u32, parsedQ: *parser.TokenQueue) Self {
        const declarations = try allocator.alloc(u32, maxSymbols);
        @memset(declarations, UNDECLARED_SENTINEL);

        const unresolved = try allocator.alloc(u32, maxSymbols);
        @memset(unresolved, UNDECLARED_SENTINEL);

        const scopeStack = std.ArrayList(Scope).init(allocator);
        // Initialize with a base module scope.
        scopeStack.append(Scope{ .start = 0, .scopeType = .base });

        return Self{ .allocator = allocator, .declarations = declarations, .unresolved = unresolved, .scopeStack = scopeStack, .parsedQ = parsedQ };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.declarations);
        self.allocator.free(self.unresolved);
        self.scopeStack.deinit();
    }

    fn declareToken(self: *Self, index: u32, token: tok.Token) tok.Token {
        const symbol = token.data.value.arg0;
        const prevDeclaration = self.declarations[symbol];
        // Index - Current parser index where this variable is being declared.
        // Symbol - Normalized Symbol ID for the variable name.
        if (prevDeclaration == UNDECLARED_SENTINEL) {
            // First seen declaration for this symbol.
            // We could give it an SSA ID here if we wanted.
            // First is the some combo of symbol + 0, second dec looks up previous ID + 1.
            self.declarations[symbol] = index;
            return token;
        } else {
            // Declare this as the latest declaration, and chain a reference to the previous declaration.
            const offset = prevDeclaration - index; // Negative offset, since index is always greater than prev.
            return tok.Token{
                .kind = token.kind,
                .data = .{ .value = .{ .arg0 = symbol, .arg1 = offset } },
                .aux = token.aux, // TODO: Likely need to reset the "aux" flag here.
            };
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
                    const offset = declarationIndex - unresolvedRefIdx; // Should be positive, since this is a forward ref.
                    // TODO: Overflow checks.

                    // Resolve this symbol ref in the parsed queue to this current declaration.
                    self.parsedQ.list.items[unresolvedRefIdx] = tok.Token{
                        .kind = ref.kind,
                        .data = .{ .value = .{ .arg0 = symbol, .arg1 = offset } },
                        .aux = ref.aux,
                    };

                    // Update pointer to the next unresolved ref in the chain.
                    if (ref.data.value.arg1 == UNDECLARED_SENTINEL) {
                        unresolvedRefIdx = ref.data.value.arg1;
                        break;
                    } else {
                        // Assume - arg1 offset is going to be negative here.
                        unresolvedRefIdx = unresolvedRefIdx + ref.data.value.arg1;
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
        const result = self.declareToken(index, token);
        // Resolve any previously unresolved refs for this given symbol.
        self.forwardDeclare(index, result);
        return result;
    }

    pub fn resolve(self: *Self, index: u32, token: tok.Token) !void {
        // Resolve a symbol to a declaration, or add it to the unresolved list if no declarations are found.
        // If there are previous unresolved refs, set this symbol's offset to that in the parsed queue.
        const symbol = token.data.value.arg0;
        if (self.declarations[symbol] == UNDECLARED_SENTINEL) {
            // No declarations found, add to unresolved list.
            self.unresolved[symbol] = index;
        } else {
            const offset = self.declarations[symbol] - index; // Should be negative.
            // Declaration found, set the offset in the parsed queue.
            return tok.Token{
                .kind = token.kind,
                .data = .{ .value = .{ .arg0 = symbol, .arg1 = offset } },
                .aux = token.aux,
            };
        }
    }

    pub fn startScope(
        self: *Self,
        scope: Scope,
    ) void {
        try self.scopeStack.append(scope);
    }

    pub fn endScope(self: *Self) void {
        _ = self.scopeStack.pop();
    }
};

// Situations:
// Same scope:
// declaration
// reference

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

// Unsupported forward-declarations remain unresolved. We may want to throw a shadowing warning?
// function scope without forward-declarations
//    reference (should remain unresolved)
//    some other sub-scope with forward-declarations
//        reference (should remain unresolved)
//    declaration
//

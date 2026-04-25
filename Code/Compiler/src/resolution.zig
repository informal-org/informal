/////////////////////////////////////////////
// Symbol Resolution
// The lexer normalizes string symbols to a numeric index.
// But not all who go by the same name are the same thing.
// The parser is responsible for contextualizing the symbol in terms of declaration vs reference per scope.
// We can do symbol-resolution without a second pass with some bookkeeping.
// As you encounter symbols, maintain a stack of declarations.
// It's straightforward to match up references to those declarations, and create an SSA-like indexed versions for assignments.
// The tricky part is forward references. When you encounter a reference to an as-yet undefined symbol,
// add its token location to a list of undefined refs at that symbol and leave a blank spot for it in the parsed queue.
// When you encounter a declaration, check which of those are "within scope" by looking at the current active scope's start index
// If token index > start index (and we know it's less than end index by iteration order)
// AND if current scope is one that supports forward declarations (objects, global support it. A function / condition block doesn't).
//
// Shadowed declarations are tracked via a bitset. On endScope, only positions with set bits need reverting.
// This is O(shadows) rather than O(scope_size) for cleanup.
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
    scopeType: ScopeType,
};

pub const UNDECLARED_SENTINEL = 0;

pub fn calcOffset(comptime T: anytype, target: u32, index: u32) T {
    const signedTarget: i32 = @intCast(target);
    const signedIndex: i32 = @intCast(index);
    const diff: i32 = signedTarget - signedIndex;
    if (@typeInfo(T).int.signedness == .signed) return @truncate(diff);
    return @truncate(@as(u32, @bitCast(diff)));
}

pub fn applyOffset(comptime signedOffsetT: anytype, index: u32, offset: anytype) u32 {
    const signedIndex: i32 = @intCast(index);
    const signedOffset: signedOffsetT = @bitCast(offset);
    return @bitCast(signedIndex + signedOffset);
}

pub const Resolution = struct {
    const Self = @This();
    allocator: std.mem.Allocator,

    // Per symbol-id: index of the current chain tail, or UNDECLARED_SENTINEL.
    // The tail is either the declaration itself (flags.declaration set, no uses yet)
    // or the most recent resolved use, whose prev_offset lands on the declaration in one hop.
    declarations: []u32,
    unresolved: []u32,

    scopeStack: std.array_list.Aligned(Scope, null),

    parsedQ: *parser.TokenQueue,

    scopeId: u16,

    pub fn init(allocator: std.mem.Allocator, maxSymbols: u32, parsedQ: *parser.TokenQueue) !Self {
        const declarations = try allocator.alloc(u32, maxSymbols);
        @memset(declarations, UNDECLARED_SENTINEL);

        const unresolved = try allocator.alloc(u32, maxSymbols);
        @memset(unresolved, UNDECLARED_SENTINEL);

        // 64 is the max scope depth enforced by lexer.
        var scopeStack = try std.array_list.Aligned(Scope, null).initCapacity(allocator, 64);
        scopeStack.appendAssumeCapacity(Scope{ .start = 0, .scopeType = .base });

        return Self{
            .allocator = allocator,
            .declarations = declarations,
            .unresolved = unresolved,
            .scopeStack = scopeStack,
            .parsedQ = parsedQ,
            .scopeId = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.declarations);
        self.allocator.free(self.unresolved);
        self.scopeStack.deinit(self.allocator);
    }

    pub fn startScope(self: *Self, scope: Scope) void {
        self.scopeStack.appendAssumeCapacity(scope);
        self.scopeId += 1;
    }

    pub fn endScope(self: *Self, index: u32) void {
        const scope = self.scopeStack.pop() orelse return;

        // Patch grp_indent start token to point to end.
        const startNode = self.parsedQ.list.items[scope.start];
        if (startNode.kind == tok.Kind.grp_indent) {
            self.parsedQ.list.items[scope.start] = tok.Token.lex(startNode.kind, index, startNode.data.scope.scope_id);
        }

        // self.revertShadows(scope.start, index);
    }

    fn getCurrentScope(self: *Self) Scope {
        return self.scopeStack.items[self.scopeStack.items.len - 1];
    }

    pub fn declare(
        self: *Self,
        index: u32,
        token: tok.Token,
    ) tok.Token {
        const sym_id = token.data.ident.symbol_id;
        const prev_tail = self.declarations[sym_id];

        var arg1: u16 = UNDECLARED_SENTINEL;

        if (prev_tail != UNDECLARED_SENTINEL) {
            // Shadowing a previous declaration. Encode the outer tail so revertShadows
            // restores the full chain, not just the outer declaration.
            arg1 = calcOffset(u16, prev_tail, index);
            // self.setShadowBit(index);
        }

        const result = token.newDeclaration(arg1);

        self.declarations[sym_id] = index;

        std.log.debug("Declared [{any}] at {any}", .{ token, index });

        self.resolveForwardDeclarations(index, sym_id);
        return result;
    }

    fn resolveForwardDeclarations(self: *Self, declarationIndex: u32, sym_id: u16) void {
        const currentScope = self.getCurrentScope();
        if (currentScope.scopeType == .module or currentScope.scopeType == .object) {
            var unresolvedRefIdx = self.unresolved[sym_id];

            while (unresolvedRefIdx != UNDECLARED_SENTINEL) {
                if (unresolvedRefIdx >= currentScope.start) {
                    const nextUnresolved_prev_offset = self.parsedQ.list.items[unresolvedRefIdx].data.ident.prev_offset;

                    const offset = calcOffset(u16, declarationIndex, unresolvedRefIdx);
                    self.parsedQ.list.items[unresolvedRefIdx].data.ident.symbol_id = sym_id;
                    self.parsedQ.list.items[unresolvedRefIdx].data.ident.prev_offset = offset;
                    self.parsedQ.list.items[unresolvedRefIdx].data.ident.next_offset = 0;

                    // Patch use-chain: previous tail's next_offset points to this resolved ref.
                    const tail = self.declarations[sym_id];
                    self.parsedQ.list.items[tail].data.ident.next_offset = calcOffset(u16, unresolvedRefIdx, tail);
                    self.declarations[sym_id] = unresolvedRefIdx;

                    if (nextUnresolved_prev_offset == UNDECLARED_SENTINEL) {
                        unresolvedRefIdx = UNDECLARED_SENTINEL;
                        break;
                    } else {
                        unresolvedRefIdx = applyOffset(i16, unresolvedRefIdx, nextUnresolved_prev_offset);
                    }
                } else {
                    break;
                }
            }
            self.unresolved[sym_id] = unresolvedRefIdx;
        }
    }

    pub fn resolve(self: *Self, index: u32, token: tok.Token) tok.Token {
        const sym_id = token.data.ident.symbol_id;
        const tail = self.declarations[sym_id];

        if (tail == UNDECLARED_SENTINEL) {
            // No declaration found. Chain into unresolved list.
            const prev_unresolved = self.unresolved[sym_id];
            const chain_offset: u16 = if (prev_unresolved != UNDECLARED_SENTINEL)
                calcOffset(u16, prev_unresolved, index)
            else
                UNDECLARED_SENTINEL;

            self.unresolved[sym_id] = index;
            std.log.debug("Resolved [{any}] unresolved", .{token});
            return tok.Token{
                .kind = token.kind,
                .data = .{ .ident = .{ .symbol_id = sym_id, .prev_offset = chain_offset, .next_offset = 0 } },
                .flags = token.flags,
            };
        }

        // Derive the declaration from the tail: it either is the declaration (no uses yet)
        // or a resolved use whose prev_offset points straight at the declaration.
        const tailToken = self.parsedQ.list.items[tail];
        const decl_idx = if (tailToken.flags.declaration)
            tail
        else
            applyOffset(i16, tail, tailToken.data.ident.prev_offset);

        const prev_offset = calcOffset(u16, decl_idx, index);

        // Patch use-chain: previous tail's next_offset points to this reference.
        self.parsedQ.list.items[tail].data.ident.next_offset = calcOffset(u16, index, tail);

        self.declarations[sym_id] = index;

        const signedOffset: i16 = @bitCast(prev_offset);
        std.log.debug("Resolved [{any}] to offset {any}", .{ token, signedOffset });

        return tok.Token{
            .kind = token.kind,
            .data = .{ .ident = .{ .symbol_id = sym_id, .prev_offset = prev_offset, .next_offset = 0 } },
            .flags = token.flags,
        };
    }
};

test {
    _ = @import("test/test_resolution.zig");
}

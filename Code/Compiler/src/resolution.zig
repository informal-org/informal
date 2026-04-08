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
    const offset: u32 = @bitCast(signedTarget - signedIndex);
    return @truncate(offset);
}

pub fn applyOffset(comptime signedOffsetT: anytype, index: u32, offset: anytype) u32 {
    const signedIndex: i32 = @intCast(index);
    const signedOffset: signedOffsetT = @bitCast(offset);
    return @bitCast(signedIndex + signedOffset);
}

pub const DeclEntry = packed struct(u64) {
    decl_index: u32,
    chain_tail: u24,
    _padding: u8 = 0,

    const ZERO: DeclEntry = .{ .decl_index = 0, .chain_tail = 0, ._padding = 0 };
};

pub const ShadowMode = enum { allow, disallow };

pub const Resolution = ResolutionImpl(.allow);

pub fn ResolutionImpl(comptime shadow_mode: ShadowMode) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,

        declarations: []DeclEntry,
        unresolved: []u32,

        shadow_masks: []u64,

        scopeStack: std.array_list.AlignedManaged(Scope, null),

        parsedQ: *parser.TokenQueue,

        scopeId: u16,

        pub fn init(allocator: std.mem.Allocator, maxSymbols: u32, parsedQ: *parser.TokenQueue) !Self {
            const declarations = try allocator.alloc(DeclEntry, maxSymbols);
            @memset(declarations, DeclEntry.ZERO);

            const unresolved = try allocator.alloc(u32, maxSymbols);
            @memset(unresolved, UNDECLARED_SENTINEL);

            var scopeStack = std.array_list.AlignedManaged(Scope, null).init(allocator);
            try scopeStack.append(Scope{ .start = 0, .scopeType = .base });

            const shadow_masks = blk: {
                const num_words = (parsedQ.list.capacity + 63) / 64;
                const masks = try allocator.alloc(u64, if (num_words == 0) 1 else num_words);
                @memset(masks, 0);
                break :blk masks;
            };

            return Self{
                .allocator = allocator,
                .declarations = declarations,
                .unresolved = unresolved,
                .shadow_masks = shadow_masks,
                .scopeStack = scopeStack,
                .parsedQ = parsedQ,
                .scopeId = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.declarations);
            self.allocator.free(self.unresolved);
            self.allocator.free(self.shadow_masks);
            self.scopeStack.deinit();
        }

        pub fn startScope(self: *Self, scope: Scope) !void {
            try self.scopeStack.append(scope);
            self.scopeId += 1;
        }

        pub fn endScope(self: *Self, index: u32) !void {
            const scope = self.scopeStack.pop() orelse return;

            // Patch grp_indent start token to point to end.
            const startNode = self.parsedQ.list.items[scope.start];
            if (startNode.kind == tok.Kind.grp_indent) {
                self.parsedQ.list.items[scope.start] = tok.Token.lex(startNode.kind, index, startNode.data.value.arg1);
            }

            self.revertShadows(scope.start, index);
        }

        fn revertShadows(self: *Self, start: u32, end: u32) void {
            const start_word = start / 64;
            const end_word = (end + 63) / 64;
            const masks_len: u32 = @intCast(self.shadow_masks.len);
            const scan_end = @min(end_word, masks_len);

            var word_idx = start_word;
            while (word_idx < scan_end) : (word_idx += 1) {
                var word = self.shadow_masks[word_idx];
                if (word == 0) continue;

                // Mask off bits outside [start, end) range.
                const base = word_idx * 64;
                if (base < start) {
                    const low_bits = start - base;
                    word &= ~((@as(u64, 1) << @intCast(low_bits)) - 1);
                }
                if (base + 64 > end) {
                    const high_bits = base + 64 - end;
                    word &= (@as(u64, 1) << @intCast(64 - high_bits)) - 1;
                }

                while (word != 0) {
                    const bit: u6 = @truncate(@ctz(word));
                    const i: u32 = base + bit;
                    word &= word - 1; // clear lowest set bit

                    const decl_token = self.parsedQ.list.items[i];
                    const sym_id = decl_token.data.value.arg0;
                    const prev_offset = decl_token.data.value.arg1;

                    if (prev_offset == UNDECLARED_SENTINEL) {
                        self.declarations[sym_id] = DeclEntry.ZERO;
                    } else {
                        const prev_decl_index = applyOffset(i16, i, prev_offset);
                        self.declarations[sym_id] = .{ .decl_index = prev_decl_index, .chain_tail = 0 };
                    }
                }

                // Clear the processed bits in the mask.
                if (base < start) {
                    const low_bits = start - base;
                    self.shadow_masks[word_idx] &= (@as(u64, 1) << @intCast(low_bits)) - 1;
                } else if (base + 64 > end) {
                    const high_bits = base + 64 - end;
                    self.shadow_masks[word_idx] &= ~((@as(u64, 1) << @intCast(64 - high_bits)) - 1);
                } else {
                    self.shadow_masks[word_idx] = 0;
                }
            }
        }

        fn getCurrentScope(self: *Self) Scope {
            return self.scopeStack.items[self.scopeStack.items.len - 1];
        }

        fn setShadowBit(self: *Self, index: u32) void {
            const word_idx = index / 64;
            // Grow shadow_masks if needed.
            if (word_idx >= self.shadow_masks.len) {
                const new_len = @max(word_idx + 1, self.shadow_masks.len * 2);
                const new_masks = self.allocator.realloc(self.shadow_masks, new_len) catch return;
                @memset(new_masks[self.shadow_masks.len..], 0);
                self.shadow_masks = new_masks;
            }
            self.shadow_masks[word_idx] |= @as(u64, 1) << @as(u6, @truncate(index % 64));
        }

        pub fn declare(
            self: *Self,
            index: u32,
            token: tok.Token,
        ) if (shadow_mode == .disallow) error{ShadowingDisallowed}!tok.Token else tok.Token {
            const sym_id = token.data.value.arg0;
            const entry = self.declarations[sym_id];
            const prev_decl_idx = entry.decl_index;

            var arg1: u16 = UNDECLARED_SENTINEL;

            if (prev_decl_idx != UNDECLARED_SENTINEL) {
                // Shadowing a previous declaration.
                if (shadow_mode == .disallow) {
                    return error.ShadowingDisallowed;
                }
                arg1 = calcOffset(u16, prev_decl_idx, index);
                self.setShadowBit(index);
            } else if (shadow_mode == .disallow) {
                // Track all declarations for scope cleanup so sibling scopes can reuse names.
                self.setShadowBit(index);
            }

            const result = token.newDeclaration(arg1);

            self.declarations[sym_id] = .{ .decl_index = index, .chain_tail = 0 };

            std.log.debug("Declared [{any}] at {any}", .{ token, index });

            self.resolveForwardDeclarations(index, sym_id);
            return result;
        }

        fn resolveForwardDeclarations(self: *Self, declarationIndex: u32, sym_id: u32) void {
            const currentScope = self.getCurrentScope();
            if (currentScope.scopeType == .module or currentScope.scopeType == .object) {
                var unresolvedRefIdx = self.unresolved[sym_id];

                while (unresolvedRefIdx != UNDECLARED_SENTINEL) {
                    if (unresolvedRefIdx >= currentScope.start) {
                        const ref = self.parsedQ.list.items[unresolvedRefIdx];
                        const offset = calcOffset(u16, declarationIndex, unresolvedRefIdx);

                        self.parsedQ.list.items[unresolvedRefIdx] = tok.Token{
                            .kind = ref.kind,
                            .data = .{ .value = .{ .arg0 = 0, .arg1 = @truncate(offset) } },
                            .aux = ref.aux,
                        };

                        // Patch use-chain: this resolved ref becomes part of the chain.
                        const entry = self.declarations[sym_id];
                        if (entry.chain_tail != 0) {
                            const prev = self.parsedQ.list.items[entry.chain_tail];
                            self.parsedQ.list.items[entry.chain_tail] = tok.Token{
                                .kind = prev.kind,
                                .data = .{ .value = .{ .arg0 = unresolvedRefIdx, .arg1 = prev.data.value.arg1 } },
                                .aux = prev.aux,
                            };
                        }
                        self.declarations[sym_id] = .{ .decl_index = declarationIndex, .chain_tail = @intCast(unresolvedRefIdx) };

                        if (ref.data.value.arg1 == UNDECLARED_SENTINEL) {
                            unresolvedRefIdx = ref.data.value.arg1;
                            break;
                        } else {
                            unresolvedRefIdx = applyOffset(i16, unresolvedRefIdx, ref.data.value.arg1);
                        }
                    } else {
                        break;
                    }
                }
                self.unresolved[sym_id] = unresolvedRefIdx;
            }
        }

        pub fn resolve(self: *Self, index: u32, token: tok.Token) tok.Token {
            const sym_id = token.data.value.arg0;
            const entry = self.declarations[sym_id];
            const decl_idx = entry.decl_index;

            if (decl_idx == UNDECLARED_SENTINEL) {
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
                    .data = .{ .value = .{ .arg0 = sym_id, .arg1 = chain_offset } },
                    .aux = token.aux,
                };
            }

            // Normal resolution.
            const offset = calcOffset(u16, decl_idx, index);

            // Patch use-chain: previous tail points to this reference.
            const tail = entry.chain_tail;
            if (tail != 0) {
                const prev = self.parsedQ.list.items[tail];
                self.parsedQ.list.items[tail] = tok.Token{
                    .kind = prev.kind,
                    .data = .{ .value = .{ .arg0 = index, .arg1 = prev.data.value.arg1 } },
                    .aux = prev.aux,
                };
            }

            self.declarations[sym_id] = .{ .decl_index = decl_idx, .chain_tail = @intCast(index) };

            const signedOffset: i16 = @bitCast(offset);
            std.log.debug("Resolved [{any}] to offset {any}", .{ token, signedOffset });

            return tok.Token{
                .kind = token.kind,
                .data = .{ .value = .{ .arg0 = 0, .arg1 = offset } },
                .aux = token.aux,
            };
        }
    };
}

test {
    _ = @import("test/test_resolution.zig");
}

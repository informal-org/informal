// A column-based tuple databased used to power the datalog queries.
// First, there's a string hashmap of Term variables to an integer ID, and a variable to store the max ID.
// Each Term also stores its 'index' within each table in sorted order.
// There's a list of Tables - one per "relation".
// Each table is composed of columns.
// The column is composed of two representations:
// An array of each distinct term element, which point to a list of indexes where that term appears in this column.
//  - The indexes are stored with a byte offset.
//  - A 0 offset indicates the value is beyond the 0-255 byte range, and appears in an auxillary array as the exact index.
// The column additionally has a raw list of byte values, indicating which term appears in that position (based on the term index)

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const assert = std.debug.assert;
const constants = @import("constants.zig");
const OffsetArray = @import("offsetarray.zig").OffsetArray;
const OffsetIterator = @import("offsetarray.zig").OffsetIterator;

pub const DB = struct {
    allocator: Allocator,
    terms: std.StringHashMap(Term),
    tables: std.StringHashMap(Table),
    max_column_id: u32 = 0,
    max_term_id: u32 = 0,
    max_table_id: u32 = 0,

    pub fn init(allocator: Allocator) DB {
        return DB{
            .allocator = allocator,
            .terms = std.StringHashMap(Term).init(allocator),
            .tables = std.StringHashMap(Table).init(allocator),
        };
    }

    pub fn deinit(self: *DB) void {
        var terms_iterator = self.terms.iterator();
        while (terms_iterator.next()) |entry| {
            var term_ptr = entry.value_ptr;
            term_ptr.deinit();
        }
        var tables_iterator = self.tables.iterator();
        while (tables_iterator.next()) |entry| {
            var table = entry.value_ptr;
            table.deinit();
            self.allocator.free(entry.key_ptr.*);
        }
        self.terms.deinit();
        self.tables.deinit();
    }

    pub fn addTable(self: *DB, name: []const u8) *Table {
        const table = Table.init(self, self.allocator, name);
        // Insert at tables for name
        if (self.tables.get(name)) |_| {
            @panic("Table already exists");
        }
        try self.tables.put(name, table);
        return table;
    }

    pub fn getOrCreateTerm(self: *DB, name: []const u8, variable: bool) *Term {
        if (self.terms.get(name)) |t| {
            assert(t.variable == variable);
            return t;
        }
        const new_term = Term.init(self.allocator);
        new_term.variable = variable;
        try self.terms.put(name, new_term);
        return new_term;
    }
};

pub const Table = struct {
    db: *DB,
    table_id: u32,
    name: []const u8,
    allocator: Allocator,
    columns: std.StringArrayHashMap(Column),

    pub fn init(db: *DB, allocator: Allocator, name: []const u8) Table {
        const table_id = db.max_table_id;
        db.max_table_id += 1;
        return Table{
            .db = db,
            .table_id = table_id,
            .allocator = allocator,
            .name = name,
            .columns = std.StringArrayHashMap(Column).init(allocator),
        };
    }

    pub fn deinit(self: *Table) void {
        var iterator = self.columns.iterator();
        while (iterator.next()) |entry| {
            var column = entry.value_ptr;
            column.deinit();
        }
        self.columns.deinit();
    }

    pub fn addColumn(self: *Table, name: []const u8) !*Column {
        const column_id = self.db.max_column_id;
        self.db.max_column_id += 1;
        const column = try Column.init(self, self.allocator, column_id);
        try self.columns.put(name, column);
        return self.columns.getPtr(name).?;
    }
};

pub const Column = struct {
    id: u32, // Global Column ID
    table: *Table,
    allocator: Allocator,
    // List of distinct terms which appear in this column. The index in this table is what's used everywhere else.
    // This list shouldn't be used much. Instead, prefer the term->column ID for lookups.
    // We could remove this and replace it with a max term ID if needed.
    terms: std.ArrayList(Term),
    // The raw list of byte values, indicating which term appears in that position (based on the term index)
    // If there are more than 255 values, then the second arraylist is used for newer terms going forward.
    order: std.ArrayList(u8),
    // Only used if there are more than 255 distinct terms (i.e. term ID overflow). Initialized to empty capacity.
    // Since columns only add, and term IDs only increase, you can conceptually think of this array as continuing where order left off.
    order16: std.ArrayList(u16),
    // Term ID -> List of its references. Indexed by the local term index.
    refs: std.ArrayList(TermRefs),
    length: u32 = 0, // Total length. Equals order.items.len + order16.items.len

    pub fn init(table: *Table, allocator: Allocator, column_id: u32) !Column {
        const emptyOrd16 = try std.ArrayList(u16).initCapacity(allocator, 0);
        return Column{
            .allocator = allocator,
            .table = table,
            .id = column_id,
            .terms = std.ArrayList(Term).init(allocator),
            .order = std.ArrayList(u8).init(allocator),
            .order16 = emptyOrd16,
            .refs = std.ArrayList(TermRefs).init(allocator),
        };
    }

    pub fn deinit(self: *Column) void {
        // The term contents will be cleaned up by the base DB.
        // for (self.terms.items) |*term| {
        //     term.deinit();
        // }
        self.terms.deinit();
        self.order.deinit();
        self.order16.deinit();
        for (self.refs.items) |*termRefs| {
            termRefs.deinit();
        }
        self.refs.deinit();
    }

    fn pushOrder(self: *Column, termIdx: u16) !u32 {
        if (self.terms.items.len < 255) {
            assert(termIdx < 255);
            const val: u8 = @truncate(termIdx);
            try self.order.append(val);
        } else {
            try self.order16.append(termIdx);
        }
        const index = self.length;
        self.length += 1;
        return index;
    }

    fn pushRef(self: *Column, termIdx: u16, orderIndex: u32) !void {
        var termRefs = &self.refs.items[termIdx];
        try termRefs.pushRef(orderIndex);
    }

    pub fn push(self: *Column, termIdx: u16) !void {
        const orderIndex = try self.pushOrder(termIdx);
        try self.pushRef(termIdx, orderIndex);
    }

    /// Add a new term to this column and push it, returning its column-relative local index.
    /// The caller is responsible for making sure it's a net-new term.
    /// Otherwise, insertion performance would be dominated by that term-existence lookup.
    pub fn addTerm(self: *Column, term: *Term) !u16 {
        const rawTermIdx = self.terms.items.len;
        assert(rawTermIdx <= std.math.maxInt(u16));
        const termIndex: u16 = @truncate(rawTermIdx);
        try self.terms.append(term.*);
        const lastIndex = try self.pushOrder(termIndex);
        const termRefs = try TermRefs.init(self.allocator, lastIndex);
        try self.refs.append(termRefs);

        // Have the term remember where it is in this column.
        try term.addColumnRef(self.id, termIndex);

        return termIndex;
    }

    pub fn pushTerm(self: *Column, term: *Term) !u16 {
        // Add if it's a new term or push existing.
        if (term.getColumnRef(self.id)) |index| {
            self.push(index);
            return index;
        } else {
            return self.addTerm(term);
        }
    }
};

const TermRefs = struct {
    /// Each column maintains an inverted index of where all each term appears
    /// Mostly stored as an offset array. 0 indicates offset overflow, which is stored in a second array.
    /// Offset from previous appearance.
    offsets: OffsetArray,

    pub fn init(allocator: Allocator, initial_index: u32) !TermRefs {
        var offsets = OffsetArray.init(allocator);
        try offsets.pushFirst(initial_index);
        return TermRefs{
            .offsets = offsets,
        };
    }

    pub fn deinit(self: *TermRefs) void {
        self.offsets.deinit();
    }

    fn pushRef(self: *TermRefs, index: u32) !void {
        try self.offsets.push(index);
    }
};

const ColumnRef = packed struct(u64) {
    column_id: u32,
    term_index: u32,
};

fn orderColumnRef(context: ColumnRef, item: ColumnRef) std.math.Order {
    return std.math.order(context.column_id, item.column_id);
}

pub const Term = struct {
    // Store a sorted arraylist of Column ID -> index of this term within that column's terms list.
    // A column may contain many terms, but it's expected that a term only makes an appearance in some small number of columns.
    refs: std.ArrayList(ColumnRef),
    // We could store this with a tagged pointer instead.
    // Or semantically as a Term ID, type, etc. to fit in a packed union.
    variable: bool = false,

    pub fn init(allocator: Allocator) Term {
        return Term{
            .refs = std.ArrayList(ColumnRef).init(allocator),
            .variable = false,
        };
    }

    pub fn deinit(self: *Term) void {
        self.refs.deinit();
    }

    pub fn getColumnRef(self: *Term, column_id: u32) ?u32 {
        // Arbitrary boundary. General intuition is that binary-search will be slower than linear for small arrays.
        if (self.refs.items.len < 128) {
            if (self.refs.items.len == 0) {
                return null;
            }
            // Linear search. Start at end and work back since queries are likely for more recent stuff.
            var i: usize = self.refs.items.len - 1;
            while (i > 0 and self.refs.items[i].column_id > column_id) {
                i -= 1;
            }
            if (self.refs.items[i].column_id == column_id) {
                return self.refs.items[i].term_index;
            }
            return null;
        } else {
            // Binary search if the list is large - which we expect to be fairly rare.
            const target = ColumnRef{ .column_id = column_id, .term_index = 0 };
            const index = std.sort.binarySearch(ColumnRef, self.refs.items, target, orderColumnRef);
            if (index == null) {
                return null;
            }
            return self.refs.items[index.?].term_index;
        }
    }

    pub fn addColumnRef(self: *Term, column_id: u32, term_index: u32) !void {
        const column_ref = ColumnRef{ .column_id = column_id, .term_index = term_index };
        var index: usize = 0;
        if (self.refs.items.len < 128) {
            if (self.refs.items.len > 0) {
                // Linear search. Start at end and work back since queries are more likely for more recent stuff.
                index = self.refs.items.len - 1;
                while (index > 0 and self.refs.items[index].column_id > column_id) {
                    index -= 1;
                }
            }
        } else {
            // insertion sort to add to refs
            index = std.sort.upperBound(ColumnRef, self.refs.items, column_ref, orderColumnRef);
        }
        // TODO: Do we need to heap-allocate column_ref?
        try self.refs.insert(index, column_ref);
    }
};

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;

test {
    if (constants.DISABLE_ZIG_LAZY) {
        @import("std").testing.refAllDecls(@This());
    }
}

test "Column - Term indexing" {
    var db = DB.init(test_allocator);
    defer db.deinit();

    var table = Table.init(&db, test_allocator, "test_table");
    defer table.deinit();

    var col = try table.addColumn("test_col");

    var term1 = Term.init(test_allocator);
    defer term1.deinit();

    var term2 = Term.init(test_allocator);
    defer term2.deinit();

    const term1_idx = try col.addTerm(&term1);
    const term2_idx = try col.addTerm(&term2);

    try expectEqual(@as(u16, 0), term1_idx);
    try expectEqual(@as(u16, 1), term2_idx);
    try expectEqual(@as(usize, 2), col.terms.items.len);

    try col.push(term2_idx);
    try col.push(term1_idx);

    // Ensure the order stores the term IDs properly.
    try expectEqual(@as(u32, 4), col.length); // 2 from addRefs, 2 from push.
    try expectEqual(@as(u8, 0), col.order.items[0]);
    try expectEqual(@as(u8, 1), col.order.items[1]);
    try expectEqual(@as(u8, 1), col.order.items[2]);
    try expectEqual(@as(u8, 0), col.order.items[3]);

    // Ensure the terms have a pointer back to their index in the column.
    try expectEqual(@as(u32, 0), term1.getColumnRef(col.id).?);
    try expectEqual(@as(u32, 1), term2.getColumnRef(col.id).?);

    // Ensure each term stores the index offsets they appear in.
    // 1 2 2 1 = term 1 refs at [0, 3]. Term 2 [0, 1]
    const term1_expected = [_]u32{ 0, 3 };
    var term1_iter = OffsetIterator{ .offsetArray = &col.refs.items[0].offsets };
    for (term1_expected) |expected| {
        const actual = term1_iter.next().?;
        std.debug.print("expected: {d}, actual: {d}\n", .{ expected, actual });
        try expectEqual(expected, actual);
    }
    assert(term1_iter.next() == null);

    const term2_expected = [_]u32{ 1, 2 };
    var term2_iter = OffsetIterator{ .offsetArray = &col.refs.items[1].offsets };
    for (term2_expected) |expected| {
        try expectEqual(expected, term2_iter.next().?);
    }
    assert(term2_iter.next() == null);
}

test "Column - Large term sets" {
    var db = DB.init(test_allocator);
    defer db.deinit();

    var table = Table.init(&db, test_allocator, "test_table");
    defer table.deinit();

    var col = try table.addColumn("test_col");

    var i: u16 = 0;
    while (i < 260) : (i += 1) {
        var term = Term.init(test_allocator);
        defer term.deinit();
        const term_idx = try col.addTerm(&term);
        try expectEqual(i, term_idx);
        try col.push(term_idx);
    }

    try expectEqual(@as(u32, 520), col.length); // 260 from addTerm calls, 260 from push calls
    // 254 * 2 = 508. After that, term ID is larger than 255. So 260-254=6 * 2 = 12
    try expectEqual(@as(usize, 508), col.order.items.len);
    try expectEqual(@as(usize, 12), col.order16.items.len);
}

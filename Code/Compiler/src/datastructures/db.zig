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
const build_options = @import("build_options");
const OffsetArray = @import("offsetarray.zig").OffsetArray;
const OffsetIterator = @import("offsetarray.zig").OffsetIterator;
const Datalog = @import("datalog.zig").Datalog;

pub const DB = struct {
    allocator: Allocator,
    terms: std.StringHashMap(*Term),
    tables: std.StringHashMap(*Table),
    max_column_id: u32 = 0,
    max_term_id: u32 = 0,
    max_table_id: u32 = 0,

    pub fn init(allocator: Allocator) DB {
        return DB{
            .allocator = allocator,
            .terms = std.StringHashMap(*Term).init(allocator),
            .tables = std.StringHashMap(*Table).init(allocator),
        };
    }

    pub fn deinit(self: *DB) void {
        var terms_iterator = self.terms.iterator();
        while (terms_iterator.next()) |entry| {
            var term_ptr = entry.value_ptr.*;
            term_ptr.deinit();
            self.allocator.destroy(term_ptr);
            self.allocator.free(entry.key_ptr.*);
        }
        var tables_iterator = self.tables.iterator();
        while (tables_iterator.next()) |entry| {
            var table_ptr = entry.value_ptr.*;
            table_ptr.deinit();
            self.allocator.destroy(table_ptr);
            self.allocator.free(entry.key_ptr.*);
        }
        self.terms.deinit();
        self.tables.deinit();
    }

    pub fn addTable(self: *DB, name: []const u8) !*Table {
        // Insert at tables for name
        if (self.tables.get(name)) |_| {
            @panic("Table already exists");
        } else {
            // Clone the name first since both Table and our hashmap need to own it
            const owned_name = try self.allocator.dupe(u8, name);
            const table = try self.allocator.create(Table);
            table.* = Table.init(self, self.allocator, owned_name);
            try self.tables.put(owned_name, table);
            return table;
        }
    }

    pub fn getOrCreateTerm(self: *DB, name: []const u8, variable: bool) !*Term {
        if (self.terms.get(name)) |t| {
            assert(t.variable == variable);
            return t;
        }
        // Create new term on the heap
        var new_term = try self.allocator.create(Term);
        errdefer self.allocator.destroy(new_term);

        new_term.* = Term.init(self.allocator);
        new_term.variable = variable;

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        try self.terms.put(owned_name, new_term);
        return new_term;
    }
};

pub const Table = struct {
    db: *DB,
    table_id: u32,
    name: []const u8, // Managed by caller
    allocator: Allocator,
    columns: std.StringArrayHashMap(*Column),

    pub fn init(db: *DB, allocator: Allocator, name: []const u8) Table {
        const table_id = db.max_table_id;
        db.max_table_id += 1;
        return Table{
            .db = db,
            .table_id = table_id,
            .allocator = allocator,
            .name = name,
            .columns = std.StringArrayHashMap(*Column).init(allocator),
        };
    }

    pub fn deinit(self: *Table) void {
        var iterator = self.columns.iterator();
        while (iterator.next()) |entry| {
            var column_ptr = entry.value_ptr.*;
            column_ptr.deinit();
            self.allocator.destroy(column_ptr);
            self.allocator.free(entry.key_ptr.*);
        }
        self.columns.deinit();
    }

    pub fn addColumn(self: *Table, name: []const u8) !*Column {
        const column_id = self.db.max_column_id;
        self.db.max_column_id += 1;
        var column_ptr = try self.allocator.create(Column);
        errdefer self.allocator.destroy(column_ptr);

        column_ptr.* = try Column.init(self, self.allocator, column_id);
        errdefer column_ptr.deinit();

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        try self.columns.put(owned_name, column_ptr);

        return column_ptr;
    }

    pub fn getColumnByIndex(self: *Table, index: u32) *Column {
        assert(index < self.columns.count());
        return self.columns.values()[index];
    }
};

pub const Column = struct {
    id: u32, // Global Column ID
    table: *Table,
    allocator: Allocator,
    // List of distinct terms which appear in this column. The index in this table is what's used everywhere else.
    // This list shouldn't be used much. Instead, prefer the term->column ID for lookups.
    // We could remove this and replace it with a max term ID if needed.
    // We could remove this and replace it with a max term ID if needed.
    terms: std.array_list.AlignedManaged(*Term, null),
    // The raw list of byte values, indicating which term appears in that position (based on the term index)
    // If there are more than 255 terms, then the second arraylist is used for newer terms going forward.
    order: std.array_list.AlignedManaged(u8, null),
    // Only used if there are more than 255 distinct terms (i.e. term ID overflow). Initialized to empty capacity.
    // Since columns only add, and term IDs only increase, you can conceptually think of this array as continuing where order left off.
    order16: std.array_list.AlignedManaged(u16, null),
    // Term ID -> List of its references. Indexed by the local term index.
    refs: std.array_list.AlignedManaged(TermRefs, null),
    length: u32 = 0, // Total length. Equals order.items.len + order16.items.len

    pub fn init(table: *Table, allocator: Allocator, column_id: u32) !Column {
        const emptyOrd16 = try std.array_list.AlignedManaged(u16, null).initCapacity(allocator, 0);
        return Column{
            .allocator = allocator,
            .table = table,
            .id = column_id,
            .terms = std.array_list.AlignedManaged(*Term, null).init(allocator),
            .order = std.array_list.AlignedManaged(u8, null).init(allocator),
            .order16 = emptyOrd16,
            .refs = std.array_list.AlignedManaged(TermRefs, null).init(allocator),
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
        try self.terms.append(term);
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
            try self.push(@truncate(index));
            return @truncate(index);
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
    refs: std.array_list.AlignedManaged(ColumnRef, null),
    // We could store this with a tagged pointer instead.
    // Or semantically as a Term ID, type, etc. to fit in a packed union.
    variable: bool = false,

    pub fn init(allocator: Allocator) Term {
        return Term{
            .refs = std.array_list.AlignedManaged(ColumnRef, null).init(allocator),
            .variable = false,
        };
    }

    pub fn deinit(self: *Term) void {
        self.refs.deinit();
    }

    pub fn getColumnRef(self: *Term, column_id: u32) ?u32 {
        if (self.refs.items.len == 0) {
            return null;
        }

        // Arbitrary boundary. General intuition is that binary-search will be slower than linear for small arrays.
        if (self.refs.items.len < 128) {
            // Linear search. Start at end and work back since queries are likely for more recent stuff.
            var i: usize = 0;
            while (i < self.refs.items.len) {
                if (self.refs.items[i].column_id == column_id) {
                    return self.refs.items[i].term_index;
                }
                i += 1;
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

test {
    _ = @import("../test/test_db.zig");
}

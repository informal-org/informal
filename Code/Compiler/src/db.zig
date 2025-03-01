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

const DB = struct {
    allocator: Allocator,
    terms: std.StringHashMap(Term),
    tables: std.ArrayList(Table),
    max_column_id: u32 = 0,
    max_term_id: u32 = 0,
    max_table_id: u32 = 0,

    pub fn init(allocator: Allocator) DB {
        return DB{
            .allocator = allocator,
            .terms = std.StringHashMap(Term).init(allocator),
            .tables = std.ArrayList(Table).init(allocator),
        };
    }

    pub fn deinit(self: *DB) void {
        self.terms.deinit();
        self.tables.deinit();
    }
};

const Table = struct {
    db: *DB,
    table_id: u32,
    name: []const u8,
    allocator: Allocator,
    columns: std.StringArrayHashMap(Column),

    pub fn init(db: *DB, allocator: Allocator, name: []const u8) Table {
        return Table{
            .db = db,
            .allocator = allocator,
            .name = name,
            .columns = std.StringArrayHashMap(Column).init(allocator),
        };
    }

    pub fn deinit(self: *Table) void {
        self.columns.deinit();
    }

    pub fn addColumn(self: *Table, name: []const u8) !u32 {
        const column_id = self.db.max_column_id;
        self.db.max_column_id += 1;
        try self.columns.put(name, Column.init(self, self.allocator, column_id));
        return column_id;
    }
};

const Column = struct {
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

    pub fn init(table: *Table, allocator: Allocator, column_id: u32) Column {
        return Column{
            .allocator = allocator,
            .table = table,
            .id = column_id,
            .terms = std.ArrayList(Term).init(allocator),
            .order = std.ArrayList(u8).init(allocator),
            .order16 = std.ArrayList(u16).initCapacity(allocator, 0),
            .refs = std.ArrayList(TermRefs).init(allocator),
        };
    }

    pub fn deinit(self: *Column) void {
        self.terms.deinit();
        self.order.deinit();
        self.order16.deinit();
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
        self.length += 1;
        return self.length;
    }

    fn pushRef(self: *Column, termIdx: u16, orderIndex: u32) !void {
        const termRefs = self.refs.items[termIdx];
        termRefs.pushRef(orderIndex);
    }

    pub fn push(self: *Column, termIdx: u16) !void {
        const orderIndex = try self.pushOrder(termIdx);
        try self.pushRef(termIdx, orderIndex);
    }

    pub fn addTerm(self: *Column, term: Term) u16 {
        // Add a new term to this column and push it.
        // The caller is responsible for making sure it's a net-new term
        // Otherwise, insertion performance would be dominated by that term-existence lookup.
        const termIndex = self.terms.items.len;
        assert(termIndex <= std.math.maxInt(u16));
        try self.terms.append(term);
        // assume: no concurrent access to self.length. And assuming we're immediately pushing this term after this call.
        const lastIndex = try self.pushOrder(termIndex);
        try self.refs.append(TermRefs{ .allocator = self.allocator, .lastIndex = lastIndex });
        return @truncate(termIndex);
    }
};

const TermRefs = struct {
    allocator: Allocator,
    // Each column maintains an inverted index of where all each term appears
    // Mostly stored as an offset array. 0 indicates offset overflow, which is stored in a second array.
    offsets: std.ArrayList(u8), // Offset from previous appearance.
    overflow: std.ArrayList(u32), // Any index where offset = 0 is found here. Else offset is offset from previous.
    lastIndex: u32, // Last absolute index where this term appeared.

    pub fn init(allocator: Allocator, initial_index: u32) TermRefs {
        var offsets = std.ArrayList(u8).init(allocator);
        var overflow = std.ArrayList(u32).init(allocator);
        // Store the initial index in the array as well
        try offsets.append(0);
        try overflow.append(initial_index);

        return TermRefs{
            .allocator = allocator,
            .offsets = offsets,
            .overflow = overflow,
            .lastIndex = initial_index,
        };
    }

    pub fn deinit(self: *TermRefs) void {
        self.offsets.deinit();
        self.overflow.deinit();
    }

    fn pushRef(self: *TermRefs, index: u32) !void {
        const offset = index - self.lastIndex;
        if (offset < 255) {
            try self.offsets.append(@truncate(offset));
        } else {
            try self.offsets.append(0);
            try self.overflow.append(offset);
        }
        self.lastIndex = index;
    }
};

const ColumnRef = packed struct(u64) {
    // TODO: Order here likely matters as a micro-optimization.
    column_id: u32,
    term_index: u32,
};

fn orderColumnRef(context: ColumnRef, item: ColumnRef) std.math.Order {
    return std.math.order(context.column_id, item.column_id);
}

const Term = struct {
    // Store a sorted arraylist of Column ID -> index of this term within that column's terms list.
    // A column may contain many terms, but it's expected that a term only makes an appearance in some small number of columns.
    refs: std.ArrayList(ColumnRef),

    pub fn init(allocator: Allocator) Term {
        return Term{
            .allocator = allocator,
            .refs = std.ArrayList(ColumnRef).init(allocator),
        };
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
            const index = std.sort.binarySearch(u32, self.refs.items, column_id, orderColumnRef);
            if (index == null) {
                return null;
            }
            return self.refs.items[index].term_index;
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

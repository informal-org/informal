const std = @import("std");
const db_mod = @import("../datastructures/db.zig");
const offsetarray = @import("../datastructures/offsetarray.zig");

const DB = db_mod.DB;
const Table = db_mod.Table;
const Column = db_mod.Column;
const Term = db_mod.Term;
const OffsetIterator = offsetarray.OffsetIterator;

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const assert = std.debug.assert;

test "Memory management test - init and deinit" {
    std.debug.print("\n=== Starting Memory management test ===\n", .{});
    var db = DB.init(test_allocator);
    defer db.deinit();

    var table = Table.init(&db, test_allocator, "test_table");
    defer table.deinit();

    var col = try table.addColumn("test_col");
    defer col.deinit();

    var term = try db.getOrCreateTerm("term1", false);
    defer term.deinit();

    std.debug.print("end of memory management test\n", .{});
}

test "Column - Term indexing" {
    std.debug.print("\n=== Starting Term indexing test ===\n", .{});
    var db = DB.init(test_allocator);
    defer db.deinit();

    var table = Table.init(&db, test_allocator, "test_table");
    defer table.deinit();

    var col = try table.addColumn("test_col");

    // Create terms through the DB to ensure proper allocation
    var term1 = try db.getOrCreateTerm("term1", false);
    var term2 = try db.getOrCreateTerm("term2", false);

    const term1_idx = try col.addTerm(term1);
    const term2_idx = try col.addTerm(term2);

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
    std.debug.print("\n=== Starting Large term sets test ===\n", .{});
    var db = DB.init(test_allocator);
    defer db.deinit();

    var table = Table.init(&db, test_allocator, "test_table");
    defer table.deinit();

    var col = try table.addColumn("test_col");

    var i: u16 = 0;
    while (i < 260) : (i += 1) {
        // Create a unique named term using the DB
        var term_name_buf: [20]u8 = undefined;
        const term_name = try std.fmt.bufPrint(&term_name_buf, "term{d}", .{i});
        const term = try db.getOrCreateTerm(term_name, false);

        const term_idx = try col.addTerm(term);
        try expectEqual(i, term_idx);
        try col.push(term_idx);
    }

    try expectEqual(@as(u32, 520), col.length); // 260 from addTerm calls, 260 from push calls
    // 254 * 2 = 508. After that, term ID is larger than 255. So 260-254=6 * 2 = 12
    try expectEqual(@as(usize, 508), col.order.items.len);
    try expectEqual(@as(usize, 12), col.order16.items.len);
}

test "Term reference stability with resizing" {
    std.debug.print("\n=== Starting Term reference stability test ===\n", .{});
    var db = DB.init(test_allocator);
    defer db.deinit();

    // Create a table with multiple columns to stress test references
    var table = try db.addTable("stability_test");
    var col1 = try table.addColumn("col1");
    var col2 = try table.addColumn("col2");
    var col3 = try table.addColumn("col3");

    const TERM_COUNT = 100; // Enough terms to cause multiple hashmap resizes
    var terms = try test_allocator.alloc(*Term, TERM_COUNT);
    defer test_allocator.free(terms);

    // First create all terms
    std.debug.print("Creating {} terms...\n", .{TERM_COUNT});
    for (0..TERM_COUNT) |i| {
        var name_buf: [20]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buf, "term{d}", .{i});
        terms[i] = try db.getOrCreateTerm(name, false);

        // Store pointers in a separate array for verification
        if (i % 20 == 0) {
            std.debug.print("Created term {d}: {*}, refs capacity: {}\n", .{ i, terms[i], terms[i].refs.capacity });
        }
    }

    // Now add terms to columns in different orders and combinations
    // This stresses the terms hashmap and the arraylist growth
    std.debug.print("Adding terms to columns...\n", .{});

    // Add every term to col1 in original order
    for (0..TERM_COUNT) |i| {
        _ = try col1.addTerm(terms[i]);
    }

    // Add all terms to col2 in reverse order
    var j: usize = TERM_COUNT;
    while (j > 0) {
        j -= 1;
        _ = try col2.addTerm(terms[j]);
    }

    // Add terms with prime indices to col3
    const primes = [_]usize{ 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97 };
    for (primes) |prime| {
        if (prime < TERM_COUNT) {
            _ = try col3.addTerm(terms[prime]);
        }
    }

    // Verify all terms are intact and have correct column references
    std.debug.print("Verifying term references...\n", .{});
    for (0..TERM_COUNT) |i| {
        const term = terms[i];
        std.debug.print("term.refs: {any} len: {}\n", .{ term.refs.items, term.refs.items.len });

        // Every term should be in col1
        const col1_ref = term.getColumnRef(col1.id);
        std.debug.print("col1_ref: {?}\n", .{col1_ref});
        try std.testing.expect(col1_ref != null);

        // Every term should be in col2 since we added all in reverse order
        const col2_ref = term.getColumnRef(col2.id);
        std.debug.print("col2_ref: {?}\n", .{col2_ref});
        try std.testing.expect(col2_ref != null);

        // Check if term is in col3 (has a prime index)
        const col3_ref = term.getColumnRef(col3.id);

        // Check for prime terms from the list
        var is_prime = false;
        for (primes) |prime| {
            if (prime == i) {
                is_prime = true;
                break;
            }
        }

        if (is_prime) {
            try std.testing.expect(col3_ref != null);
        } else {
            try std.testing.expect(col3_ref == null);
        }
    }

    // Test rapid addition and lookup to stress memory management
    std.debug.print("Testing rapid term operations...\n", .{});
    for (0..1000) |i| {
        const term_idx = i % TERM_COUNT;
        const term = terms[term_idx];

        // Alternate between different operations
        switch (i % 3) {
            0 => {
                // Push to col1
                _ = try col1.pushTerm(term);
            },
            1 => {
                // Look up in different columns
                _ = term.getColumnRef(col1.id);
                _ = term.getColumnRef(col2.id);
                _ = term.getColumnRef(col3.id);
            },
            2 => {
                // Create a temporary term and relate it to this one
                var name_buf: [30]u8 = undefined;
                const name = try std.fmt.bufPrint(&name_buf, "temp_term{d}_{d}", .{ term_idx, i });
                const temp_term = try db.getOrCreateTerm(name, false);
                _ = try col1.addTerm(temp_term);
            },
            else => unreachable,
        }
    }

    std.debug.print("=== Term reference stability test completed ===\n", .{});
}

test "Table and Column pointer stability" {
    std.debug.print("\n=== Starting Table and Column pointer stability test ===\n", .{});
    var db = DB.init(test_allocator);
    defer db.deinit();

    const TABLE_COUNT = 10;
    const COLUMN_COUNT = 5;

    // Arrays to store pointers for later verification
    var tables = try test_allocator.alloc(*Table, TABLE_COUNT);
    defer test_allocator.free(tables);

    var columns = try test_allocator.alloc(*Column, TABLE_COUNT * COLUMN_COUNT);
    defer test_allocator.free(columns);

    // Create tables with columns
    std.debug.print("Creating {} tables with {} columns each...\n", .{ TABLE_COUNT, COLUMN_COUNT });

    for (0..TABLE_COUNT) |t| {
        var table_name_buf: [20]u8 = undefined;
        const table_name = try std.fmt.bufPrint(&table_name_buf, "table{d}", .{t});
        tables[t] = try db.addTable(table_name);

        std.debug.print("Created table {d}: {*}\n", .{ t, tables[t] });

        // Add columns to each table
        for (0..COLUMN_COUNT) |c| {
            var col_name_buf: [20]u8 = undefined;
            const col_name = try std.fmt.bufPrint(&col_name_buf, "col{d}", .{c});
            const col_index = t * COLUMN_COUNT + c;
            columns[col_index] = try tables[t].addColumn(col_name);

            std.debug.print("  Added column {d}: {*}\n", .{ c, columns[col_index] });
        }
    }

    // Add some terms to each column to force memory allocations
    std.debug.print("Adding terms to columns...\n", .{});

    for (0..TABLE_COUNT) |t| {
        for (0..COLUMN_COUNT) |c| {
            const col_index = t * COLUMN_COUNT + c;
            const column = columns[col_index];

            // Add 5 terms to each column
            for (0..5) |i| {
                var term_name_buf: [30]u8 = undefined;
                const term_name = try std.fmt.bufPrint(&term_name_buf, "term_t{d}_c{d}_{d}", .{ t, c, i });
                const term = try db.getOrCreateTerm(term_name, false);
                _ = try column.addTerm(term);
            }
        }
    }

    // Verify all tables and columns are still accessible with correct data
    std.debug.print("Verifying table and column integrity...\n", .{});

    for (0..TABLE_COUNT) |t| {
        const table = tables[t];

        // Check table properties
        try std.testing.expect(table.table_id < db.max_table_id);
        try std.testing.expectEqual(table.columns.count(), COLUMN_COUNT);

        // Check each column in this table
        for (0..COLUMN_COUNT) |c| {
            const col_index = t * COLUMN_COUNT + c;
            const column = columns[col_index];

            // Verify column properties
            try std.testing.expect(column.id < db.max_column_id);
            try std.testing.expectEqual(column.table, table);
            try std.testing.expectEqual(column.terms.items.len, 5); // We added 5 terms
        }
    }

    // Test interleaved operations to stress memory management
    std.debug.print("Testing interleaved operations...\n", .{});

    // Create additional tables and columns while accessing existing ones
    for (0..5) |i| {
        // Create a new table
        var table_name_buf: [20]u8 = undefined;
        const table_name = try std.fmt.bufPrint(&table_name_buf, "extra_table{d}", .{i});
        const extra_table = try db.addTable(table_name);

        // Add a column to the new table
        const extra_col = try extra_table.addColumn("extra_col");

        // Access random existing tables and columns
        const table_idx = i % TABLE_COUNT;
        const existing_table = tables[table_idx];

        // Verify previously created table is still valid
        try std.testing.expectEqual(existing_table.columns.count(), COLUMN_COUNT);

        // Access a column from the existing table
        const col_idx = (i * 7) % COLUMN_COUNT; // Use a non-linear pattern
        const col_index = table_idx * COLUMN_COUNT + col_idx;
        const existing_column = columns[col_index];

        // Verify the column and add a term to it
        try std.testing.expectEqual(existing_column.table, existing_table);

        var term_name_buf: [30]u8 = undefined;
        const term_name = try std.fmt.bufPrint(&term_name_buf, "interleaved_term_{d}", .{i});
        const term = try db.getOrCreateTerm(term_name, false);

        // Add the term to both the existing column and new column
        _ = try existing_column.addTerm(term);
        _ = try extra_col.addTerm(term);

        // Verify the term was added correctly
        try std.testing.expect(term.getColumnRef(existing_column.id) != null);
        try std.testing.expect(term.getColumnRef(extra_col.id) != null);
    }

    std.debug.print("=== Table and Column pointer stability test completed ===\n", .{});
}

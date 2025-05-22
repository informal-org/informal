const std = @import("std");
const db = @import("db.zig");
const DB = db.DB;
const Table = db.Table;
const Term = db.Term;
const assert = std.debug.assert;
const offsetarray = @import("offsetarray.zig");
const OffsetIterator = offsetarray.OffsetIterator;

pub const Bindings = struct {
    variable: *Term,
    values: std.ArrayList(*Term),
};

pub const Datalog = struct {
    allocator: std.mem.Allocator,
    db: DB,

    pub fn init(allocator: std.mem.Allocator) Datalog {
        return Datalog{
            .allocator = allocator,
            .db = DB.init(allocator),
        };
    }

    pub fn deinit(self: *Datalog) void {
        self.db.deinit();
    }

    pub fn addRelation(self: *Datalog, relation_name: []const u8, attributes: []const []const u8) !*Table {
        const table = try self.db.addTable(relation_name);
        for (attributes) |attribute| {
            _ = try table.addColumn(attribute);
        }
        return table;
    }

    pub fn addFact(_: *Datalog, relation: *Table, facts: []const *Term) !void {
        assert(facts.len == relation.columns.count());
        // Zip columns with each entry in row and call addTerm
        const columns = relation.columns.values();
        for (0.., columns) |i, column| {
            _ = try column.pushTerm(facts[i]);
        }
    }

    // TODO: return !?[]const Bindings
    pub fn query(self: *Datalog, relation: *Table, pattern: []const *Term) void {
        // Response can return the full facts, but it'll just be redundant with a lot of duplicate terms.
        // Instead, it's more useful to just return the binds for each variable.

        // TODO: Handle the multiple variable case.
        // var binds = std.ArrayList(*Bindings).init(self.allocator);
        // Indexes of the rows which match all constraints.

        assert(pattern.len == relation.columns.count());

        // List of iterators to the indexes each value appears at.
        var ref_indexes = std.ArrayList(*OffsetIterator).init(self.allocator);
        var variable_count = 0;

        for (0.., pattern) |i, t| {
            if (!t.*.isVariable()) {
                // ID of this term within this relation.
                const column = relation.getColumnByIndex(i);
                const relTermId = t.*.getColumnRef(column.id);
                if (relTermId == null) {
                    return null;
                }
                // Where this term appears in this column
                // TODO: Benchmark converting this merge operation to sparse bitset.
                // Current version is likely better (due to its skip behavior), but the bitset can process more at once.
                const termRefs = column.refs[relTermId.?];
                try ref_indexes.append(OffsetIterator{ .offsetArray = &termRefs.offsets });
            } else {
                variable_count += 1;
            }
        }

        // Now join all of these offsets to find our final list.
        var merged = std.ArrayList(u32).init(self.allocator);
        offsetarray.offsetJoin(ref_indexes.items, &merged);

        if (variable_count == 0) {
            // Still return something to indicate whether we found any matches or not.
        }

        return merged;
    }

    pub fn term(self: *Datalog, name: []const u8) !*Term {
        return try self.db.getOrCreateTerm(name, false);
    }

    pub fn variable(self: *Datalog, name: []const u8) !*Term {
        return try self.db.getOrCreateTerm(name, true);
    }
};

test "Ancestor relations" {
    std.debug.print("\n=== Starting Ancestor relations test ===\n", .{});
    // Part 1: Express facts
    // parent(c, cpp).
    // parent(cpp, java).
    // parent(java, scala).
    // parent(java, clojure).
    // parent(lisp, clojure).
    // parent(java, kotlin).

    var dl = Datalog.init(std.testing.allocator);
    defer dl.deinit();

    const parent_rel = try dl.addRelation("parent", &[_][]const u8{ "parent", "child" });

    const c = try dl.term("c");
    const cpp = try dl.term("cpp");
    const java = try dl.term("java");
    const scala = try dl.term("scala");
    const clojure = try dl.term("clojure");
    const lisp = try dl.term("lisp");
    const kotlin = try dl.term("kotlin");

    try dl.addFact(parent_rel, &[_]*Term{ c, cpp });
    try dl.addFact(parent_rel, &[_]*Term{ cpp, java });
    try dl.addFact(parent_rel, &[_]*Term{ java, scala });
    try dl.addFact(parent_rel, &[_]*Term{ java, clojure });
    try dl.addFact(parent_rel, &[_]*Term{ lisp, clojure });
    try dl.addFact(parent_rel, &[_]*Term{ java, kotlin });

    std.debug.print("=== Ancestor relations test completed ===\n", .{});

    // Be able to query with variables that match a pattern.
    const childVar = try dl.variable("child");
    const qJavaChilds = try dl.query(parent_rel, &[_]*Term{ java, childVar });
    std.debug.print("Java childs: {s}\n", .{qJavaChilds});
}

const std = @import("std");
const db = @import("db.zig");
const DB = db.DB;
const Table = db.Table;
const Term = db.Term;
const assert = std.debug.assert;

const Datalog = struct {
    allocator: std.mem.Allocator,
    db: *DB,

    pub fn init(allocator: std.mem.Allocator) Datalog {
        return Datalog{
            .allocator = allocator,
            .db = DB.init(allocator),
        };
    }

    pub fn deinit(self: *Datalog) void {
        self.db.deinit();
    }

    pub fn addRelation(self: *Datalog, relation_name: []const u8, attributes: []const []const u8) *Table {
        const table = self.db.addTable(relation_name);
        for (attributes) |attribute| {
            table.addColumn(attribute);
        }
        return table;
    }

    pub fn addFact(_: *Datalog, relation: *Table, facts: []*const Term) !void {
        assert(facts.len == relation.columns.count());
        // Zip columns with each entry in row and call addTerm
        for (0.., relation.columns.values()) |i, column| {
            try column.pushTerm(facts[i]);
        }
    }

    pub fn term(self: *Datalog, name: []const u8) *Term {
        return self.db.getOrCreateTerm(name, false);
    }

    pub fn variable(self: *Datalog, name: []const u8) *Term {
        return self.db.getOrCreateTerm(name, true);
    }
};

test "Ancestor relations" {
    // Part 1: Express facts
    // parent(c, cpp).
    // parent(cpp, java).
    // parent(java, scala).
    // parent(java, clojure).
    // parent(lisp, clojure).
    // parent(java, kotlin).

    var dl = Datalog.init(std.testing.allocator);
    defer dl.deinit();

    // Define the parent relation schema.
    const parent_rel = dl.addRelation("parent", &[_][]const u8{ "parent", "child" });

    // Pre-define terms.
    const c = dl.term("c");
    const cpp = dl.term("cpp");
    const java = dl.term("java");
    const scala = dl.term("scala");
    const clojure = dl.term("clojure");
    const lisp = dl.term("lisp");
    const kotlin = dl.term("kotlin");

    // Add facts
    try dl.addFact(parent_rel, &[_]*const Term{ c, cpp });
    try dl.addFact(parent_rel, &[_]*const Term{ cpp, java });
    try dl.addFact(parent_rel, &[_]*const Term{ java, scala });
    try dl.addFact(parent_rel, &[_]*const Term{ java, clojure });
    try dl.addFact(parent_rel, &[_]*const Term{ lisp, clojure });
    try dl.addFact(parent_rel, &[_]*const Term{ java, kotlin });
}

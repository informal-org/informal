const std = @import("std");
const db = @import("db.zig");
const DB = db.DB;
const Table = db.Table;
const Term = db.Term;
const assert = std.debug.assert;

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

    var facts1 = [_]*Term{ c, cpp };
    try dl.addFact(parent_rel, &facts1);

    var facts2 = [_]*Term{ cpp, java };
    try dl.addFact(parent_rel, &facts2);

    var facts3 = [_]*Term{ java, scala };
    try dl.addFact(parent_rel, &facts3);

    var facts4 = [_]*Term{ java, clojure };
    try dl.addFact(parent_rel, &facts4);

    var facts5 = [_]*Term{ lisp, clojure };
    try dl.addFact(parent_rel, &facts5);

    var facts6 = [_]*Term{ java, kotlin };
    try dl.addFact(parent_rel, &facts6);

    std.debug.print("=== Ancestor relations test completed ===\n", .{});
}

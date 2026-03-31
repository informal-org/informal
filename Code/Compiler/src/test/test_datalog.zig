const std = @import("std");
const datalog_mod = @import("../datastructures/datalog.zig");
const db_mod = @import("../datastructures/db.zig");

const Datalog = datalog_mod.Datalog;
const Term = db_mod.Term;

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

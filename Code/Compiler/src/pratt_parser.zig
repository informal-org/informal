const tok = @import("token.zig");
const Kind = tok.Kind;
const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const q = @import("queue.zig");
const rs = @import("resolution.zig");

const Token = tok.Token;
pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
pub const OffsetQueue = q.Queue(u16, 0);
const Allocator = std.mem.Allocator;

pub const PrattParser = struct {
    const Self = @This();
    buffer: []const u8,
    syntaxQ: *TokenQueue,
    auxQ: *TokenQueue,
    resolution: *rs.Resolution,
    allocator: Allocator,

    rules: [64]ParseRule,

    const LeftBindingPower = enum(u8) {
        None = 0,
        Separator = 10,
        Assign = 20,
        Or = 30,
        And = 40,
        Equality = 50,
        Comparison = 60,
        Divisive = 70,
        Additive = 80,
        Exp = 90,
        Unary = 100,
        Member = 110,
        Call = 120,
    };

    const RuleType = enum { none, literal, identifier, callExpr, unaryOp, binaryOp, binaryRightAssocOp, assignOp, colonAssocOp, separator, skipNewLine, groupParen, groupBracket, groupBrace, indentBlock, kwPrefix };

    const ParseRule = packed struct(u32) {
        // Compact pratt rule representations. Aviods storing function pointers directly, but requires an extra level of indirection.
        prefix: RuleType = .none, // What does this token mean at the start of an expression with nothing to its left? Null denotation.
        infix: RuleType = .none, // What does this token mean when it follows some expression? Left denotation.
        power: LeftBindingPower = .None, // Left binding power
    };

    fn define(self: *Self, kind: Kind, rule: ParseRule) void {
        self.rules[@intFromEnum(kind)] = rule;
    }

    fn initRules(self: *Self) void {
        assert(tok.AUX_KIND_START <= 64);
        for (0..64) |i| {
            self.rules[i] = ParseRule{};
        }

        self.define(Kind.lit_number, ParseRule{ .prefix = .literal });
        self.define(Kind.lit_string, ParseRule{ .prefix = .literal });
        self.define(Kind.lit_bool, ParseRule{ .prefix = .literal });
        self.define(Kind.lit_null, ParseRule{ .prefix = .literal });
        self.define(Kind.identifier, ParseRule{ .prefix = .identifier });
        self.define(Kind.const_identifier, ParseRule{ .prefix = .identifier });
        self.define(Kind.call_identifier, ParseRule{ .prefix = .callExpr });

        // Unary ops (prefix only)
        self.define(Kind.op_not, ParseRule{ .prefix = .unaryOp, .power = .Unary });
        self.define(Kind.op_unary_minus, ParseRule{ .prefix = .unaryOp, .power = .Unary });

        // Binary arithmetic
        self.define(Kind.op_add, ParseRule{ .infix = .binaryOp, .power = .Additive });
        self.define(Kind.op_sub, ParseRule{ .infix = .binaryOp, .power = .Additive });

        self.define(Kind.op_mul, ParseRule{ .infix = .binaryOp, .power = .Divisive });
        self.define(Kind.op_div, ParseRule{ .infix = .binaryOp, .power = .Divisive });
        self.define(Kind.op_mod, ParseRule{ .infix = .binaryOp, .power = .Divisive });
        self.define(Kind.op_pow, ParseRule{ .infix = .binaryRightAssocOp, .power = .Exp });

        // Comparison
        self.define(Kind.op_lt, ParseRule{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_gt, ParseRule{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_lte, ParseRule{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_gte, ParseRule{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_dbl_eq, ParseRule{ .infix = .binaryOp, .power = .Equality });
        self.define(Kind.op_not_eq, ParseRule{ .infix = .binaryOp, .power = .Equality });

        // Logical
        self.define(Kind.op_and, ParseRule{ .infix = .binaryOp, .power = .And });
        self.define(Kind.op_or, ParseRule{ .infix = .binaryOp, .power = .Or });

        // Assignment
        self.define(Kind.op_assign_eq, ParseRule{ .infix = .assignOp, .power = .Assign });
        self.define(Kind.op_plus_eq, ParseRule{ .infix = .assignOp, .power = .Assign });
        self.define(Kind.op_minus_eq, ParseRule{ .infix = .assignOp, .power = .Assign });
        self.define(Kind.op_mul_eq, ParseRule{ .infix = .assignOp, .power = .Assign });
        self.define(Kind.op_div_eq, ParseRule{ .infix = .assignOp, .power = .Assign });

        // Other binary
        self.define(Kind.op_choice, ParseRule{ .infix = .binaryOp, .power = .Or });
        self.define(Kind.op_in, ParseRule{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_is, ParseRule{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_as, ParseRule{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_identifier, ParseRule{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_dot_member, ParseRule{ .infix = .binaryOp, .power = .Member });

        // Separators
        self.define(Kind.sep_comma, ParseRule{ .infix = .separator, .power = .Separator });
        self.define(Kind.sep_newline, ParseRule{ .prefix = .skipNewLine, .infix = .separator, .power = .Separator });

        // Grouping
        self.define(Kind.grp_open_paren, ParseRule{ .prefix = .groupParen });
        self.define(Kind.grp_open_bracket, ParseRule{ .prefix = .groupBracket });
        self.define(Kind.grp_open_brace, ParseRule{ .prefix = .groupBrace });
        self.define(Kind.grp_indent, ParseRule{ .prefix = .indentBlock });
        self.define(Kind.grp_dedent, ParseRule{ .prefix = .dedentBlock });

        // TODO: Keywords like if, for, fn, etc.
    }
};

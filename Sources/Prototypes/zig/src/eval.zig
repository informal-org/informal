const Interpreter = struct {
    const Self = @This();
    allocator: Allocator,
    lexer: Lexer,
    parser: Parser,

    pub fn eval(self: *Self, forms: []const Form, env: []const Form) u64 {
        // Evaluate a list of forms, return the last result.
    }

    // pub fn apply(self: *Self, definition: Form, application: Form) Form {
    //     //
    // }
    
    pub fn match(self: *Self, pattern: Form, form: Form) ?Form {
        // Match all branches of one form against another.
        if(pattern.head == form.head) {
            return Form{ .head = pattern.value, .body = form.body };
        }
        // Else - check if reference. Then recurse.
    }

    pub fn choice_match(self: *Self, patterns: []const Form, form: Form) ?Form {
        // Find the first choice that matches.
        for(patterns) |pattern| {
            if(self.match(pattern, form)) |result| {
                return result;
            }
        }
    }

    pub fn structural_match(self: *Self, patterns: []const Form, form: Form) ?Form {
        // Match all branches of one form against another.
        var env = [];
        for(patterns) |pattern, i| {
            if(self.match(pattern, form.body[i])) |result| {
                env.append(result);
            } else {
                return null;
            }
        }
    }


    pub fn apply_match(self: *Self, pattern: Form, form: Form) ?Form {
        // Apply a pattern to a form, and return the last result.
        var env = [];
        for(patterns) |pattern, i| {
            env.append(self.match(pattern, env));
        }
    }

    // Match all.

}

// a : 9
// b : a
// c : {0: 9, 1: 7}

// d : 
//  {0: 9, 1: 7} :
//      7
// >> { d : { {0: 9, 1: 7} : 7 } }

// eval({ d : {0: a, 1: 7} }). 
// >> 7
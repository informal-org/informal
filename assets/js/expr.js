import * as jsep from "jsep"

// Override default jsep expressions with our language equivalents.
// Semi case-insensitive. Done at the parser level so we get clean input.
jsep.addBinaryOp("OR", 1);
jsep.addBinaryOp("Or", 1);
jsep.addBinaryOp("or", 1);

jsep.addBinaryOp("AND", 2);
jsep.addBinaryOp("And", 2);
jsep.addBinaryOp("and", 2);

jsep.addBinaryOp("MOD", 10);
jsep.addBinaryOp("Mod", 10);
jsep.addBinaryOp("mod", 10);

jsep.addBinaryOp("IS", 6);  // 6 is Priority of ==
jsep.addBinaryOp("Is", 6);
jsep.addBinaryOp("is", 6);

jsep.addUnaryOp("NOT");
jsep.addUnaryOp("Not");
jsep.addUnaryOp("not");

// Remove un-supported operations - use verbal names for these instead. 
jsep.removeBinaryOp("%");
jsep.removeBinaryOp("||");
jsep.removeBinaryOp("&&");
jsep.removeBinaryOp("|");
jsep.removeBinaryOp("&");
jsep.removeBinaryOp("==");
jsep.removeBinaryOp("!=");  // not (a = b). Excel does <>
jsep.removeBinaryOp("===");
jsep.removeBinaryOp("!==");
jsep.removeBinaryOp("<<");
jsep.removeBinaryOp(">>");
jsep.removeBinaryOp(">>>");

jsep.removeUnaryOp("!")
jsep.removeUnaryOp("~")

jsep.addLiteral("True", true)
jsep.addLiteral("TRUE", true)

jsep.addLiteral("False", false)
jsep.addLiteral("FALSE", false)

export function getDependencies(node) {
    /**
    Parse through an expression tree and return list of dependencies 
    Node: JSEP parsed root node.

    Return: List of dependency IDs
    */
    if(node.type === "BinaryExpression") {
        let left = getDependencies(node.left);
        let right = getDependencies(node.right);
        return left.concat(right);
    } else if(node.type === "UnaryExpression") {
        return getDependencies(node.argument);
    } else if(node.type === "Literal") {
        return []
    } else if(node.type === "Identifier") {
        // TODO: Validate true/false is no longer an identifier
        let uname = node.name.toUpperCase();
        // if(uname in BUILTIN_FUN){
        //     return [];
        // }

        // todo LOOKUP NAME
        return [node.name]
    
    } else if (node.type === "Compound") {
        // a, b
        let deps = [];
        node.body.map((subnode) => {
            deps.concat(getDependencies(subnode))
        });
        return deps;
    } else if (node.type == "ThisExpression") {
        return [];
    } else if(node.type == "MemberExpression") {
        console.log("Unsupported member expression");
        // Assert: This 
        return [node.name];
    } else if (node.type == "CallExpression") {
        // TODO: Also add function when user definable functions are possible.

        let depArgs = [];
        node.arguments.forEach(subnode => {
            depArgs.concat(getDependencies(subnode));
        })

        return depArgs;
    } else {
        console.log("UNHANDLED eval CASE")
        console.log(node);

        // Node.type == Identifier
        // Name lookup
        // TODO: Handle name errors better.
        // TODO: Support [bracket name] syntax for spaces.
        return [node.name];
    }
}

export function parseExpr(expr) {
    let parsed = jsep(expr)
    console.log(parsed);
    return parsed;
}
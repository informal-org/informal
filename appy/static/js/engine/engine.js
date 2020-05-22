
// Dict, Value -> value | null
export function resolveMember(node, context) {
    // cell4.name.blah
    // { "type": "MemberExpression", "computed": false, 
    // "object": { "type": "MemberExpression", "computed": false, 
        // "object": { "type": "Identifier", "name": "cell4" }, 
        // "property": { "type": "Identifier", "name": "name" } }, 
    // "property": { "type": "Identifier", "name": "blah" } } 
    // Object could be recursive for nested a.b.c style lookup.
    // let object = null;

    // let subnode = node;
    // while(node) {

    // }
    // let object = context.resolve(node.object.name);
    // if(object !== null){
    //     return object.resolve(node.property.name)
    // }
    // console.log(node);
    let object = null;
    if(node.object.type === "MemberExpression"){
        object = resolveMember(node.object, context);
    } else {
        // Assert is identifier
        object = context.resolve(node.object.name);
    }

    // console.log("object is");
    // console.log(object.name);

    if(object !== null){
        return object.resolve(node.property.name);
    }
    return null;
}

function isBoolean(value) {
    let lower = value.toLowerCase();
    return lower == "true" || lower == "false"
}

// Returns cell id
function resolve(state, name, scope) {
    var matches = state.byName[name];
    // TODO: Implement scope resolution
    if(matches !== undefined && matches.length > 0) {
        return matches[0]
    }
    return null
}

export function getDependencies(node, context) {
    /* Parse through an expression tree and return list of dependencies */
    if(node.type === "BinaryExpression") {
        let left = getDependencies(node.left, context)
        let right = getDependencies(node.right, context);
        return left.concat(right);
    } else if(node.type === "UnaryExpression") {
        return getDependencies(node.argument, context);
    } else if(node.type === "Literal") {
        return []
    } else if(node.type === "Identifier") {
        let uname = node.name.toUpperCase();
        if(uname in BUILTIN_SYMBOLS){
            return [];
        }

        // todo LOOKUP NAME
        let id_resolution = resolve(context, node.name, null)
        if(id_resolution !== undefined && id_resolution !== null) {
            return [id_resolution]
        }
        return []
    
    } else if (node.type === "Compound") {
        // a, b
        let deps = [];
        return node.body.map((subnode) => {
            deps.concat(getDependencies(subnode, context))
        });
        return deps;
    } else if (node.type == "ThisExpression") {
        return [];
    } else if(node.type == "MemberExpression") {
        return [resolveMember(node, context)];
    } else if (node.type == "CallExpression") {
        // TODO: Also add function when user definable functions are possible.

        let depArgs = [];
        node.arguments.forEach(subnode => {
            depArgs.concat(getDependencies(subnode, context));
        })

        return depArgs;
    } else {
        console.log("UNHANDLED eval CASE")
        console.log(node);

        // Node.type == Identifier
        // Name lookup
        // TODO: Handle name errors better.
        // TODO: Support [bracket name] syntax for spaces.
        return [context.resolve(node.name)];
    }
}


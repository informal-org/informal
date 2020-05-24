
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


export function evaluate(state) {
    console.log("Evaluating");
    console.log(state);
    
    // 0: {id: 0, output: "Hello 2", error: ""}
    let output = [];
    let cells = state.cellsReducer.byId;
    let parsed = parseAll(cells);

    let code = generateCode(parsed);
    let result = execJs(code);
    console.log("Final result");
    console.log(result);

    for(var cell_id in cells) {
        var element = cells[cell_id];
        output.push({
            id: element.id,
            value: result[element.id],
            error: ""
        });
    }
    // expr.body.forEach(element => {
    //     let code = generateCode(element);
    //     let result = execCode(code);

    //     output.push({
    //         id: element.id,
    //         output: result,
    //         error: ""
    //     });
    // });
    console.log(output);

    return {'results': output}
}

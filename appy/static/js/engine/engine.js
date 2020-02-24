import jsep from "jsep";


function parse() {

}

function computeDeps() {

}

function generateCode(cell) {
    // {id, name, input}
    // TODO: Generate safe names
    var variable_name = cell.name;

    return `var ${variable_name} = ${cell.input}; ${cell.input}`;
}

function execCode(code) {
    // TODO: Sandboxed execution
    return eval(code);
}

export function evaluate(expr) {
    console.log("Evaluating");
    console.log(expr);
    console.log(expr.body[0]);

    // 0: {id: 0, output: "Hello 2", error: ""}
    let output = [];
    expr.body.forEach(element => {
        let code = generateCode(element);
        let result = execCode(code);

        output.push({
            id: element.id,
            output: result,
            error: ""
        });
    });
    console.log(output);

    return {'results': output}
}

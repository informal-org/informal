import jsep from "jsep";


function parse() {

}

function computeDeps() {

}

function generateCode(expr) {
    // {id, name, input}
    // TODO: Generate safe names
    // var variable_name = cell.name;

    // return `var ${variable_name} = ${cell.input}; ${cell.input}`;

    function ctx_init() {
        var ctx = {};
        return {
            set: function(k, v) { ctx[k] = v; },
            get: function(k) { return ctx[k]; },
            all: function() { return ctx }
        };
    };

    var code = "" + ctx_init.toString() + "\n; var ctx = ctx_init();";
    expr.body.forEach((cell) => {
        var variable_name = cell.name;
        code += `var ${variable_name} = ${cell.input};\n`;
        code += `ctx.set(${cell.id}, ${variable_name});\n`;
    })

    code += "ctx.all();\n"

    console.log(code);
    return code;
}

function execCode(code) {
    // TODO: Sandboxed execution
    return eval(code);
}

export function evaluate(expr) {
    console.log("Evaluating");
    console.log(expr);
    
    // 0: {id: 0, output: "Hello 2", error: ""}
    let output = [];
    let code = generateCode(expr);
    let result = execCode(code);
    console.log("Final result");
    console.log(result);

    expr.body.forEach((element) => {
        output.push({
            id: element.id,
            output: result[element.id],
            error: ""
        });
    });
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

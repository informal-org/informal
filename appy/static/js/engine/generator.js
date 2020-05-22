
function generateCode(cells) {
    // {id, name, input}
    // TODO: Generate safe names
    // var variable_name = cell.name;

    // return `var ${variable_name} = ${cell.input}; ${cell.input}`;

    var code = `
    function ctx_init() {
        var ctx = {};
        return {
            set: function(k, v) { ctx[k] = v; },
            get: function(k) { return ctx[k]; },
            all: function() { return ctx }
        };
    };
    var ctx = ctx_init();
    `;

    for(var cell_id in cells) {
        var cell = cells[cell_id];
        if(cell.expr !== undefined && cell.expr !== null && cell.expr !== "") {
            console.log(cell);
            var variable_name = cell.name ? cell.name : "a" + cell.id;

            code += `var ${variable_name} = ${cell.expr};\n`;
            code += `ctx.set("${cell.id}", ${variable_name});\n`;
        }

    }

    code += "ctx.all();\n"

    console.log(code);
    return code;
}

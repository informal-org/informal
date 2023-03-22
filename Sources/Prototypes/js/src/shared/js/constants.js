
// TODO: Ensure error equality on CYCLIC_ERR throws error.
export const JS_PRE_CODE = `
function ctx_init() {
    var ctx = {};
    return {
        set: function(k, v) { ctx[k] = {value: v}; },
        setError: function(k, v) { ctx[k] = {error: v}; },
        get: function(k) { return ctx[k].value; },
        getError: function(k) { return ctx[k].error; },
        all: function() { return ctx }
    };
};
var ctx = ctx_init();
`;


// End wrapper function
export const JS_POST_CODE = `return ctx.all();\n`;

// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

import * as jsep from "jsep"

var parse_tree = jsep("1 + 1");
console.log(parse_tree)

function parse_expr(event) {
    event.preventDefault();
    var expr = document.getElementById("expr-input").value;
    console.log(jsep(expr));


    return false;
}

console.log("my code")
var expr_form = document.getElementById("expr-form");
expr_form.addEventListener("submit", parse_expr, true);
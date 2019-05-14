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


function postData(url = '', data = {}) {
    return fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data), // body data type must match "Content-Type" header
    })
    .then(response => response.json()); 
}

function parse_expr(event) {
    event.preventDefault();
    var expr = document.getElementById("expr-input").value;
    var parsed = jsep(expr);
    console.log(parsed);
    
    postData("/api/evaluate", parsed).then(
        (json) => {
            console.log(json);
        }
    )

    return false;
}

console.log("my code")
var expr_form = document.getElementById("expr-form");
expr_form.addEventListener("submit", parse_expr, true);
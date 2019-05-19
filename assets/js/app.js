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
    .then((response) =>{
        if(response.ok) {
            return response.json();
        }
        throw new Error('Network response was not ok.');
    })
}

import LiveSocket from "phoenix_live_view"
import View from "phoenix_live_view"

let liveSocket = new LiveSocket("/live")
liveSocket.connect()

window.phxSocket = liveSocket;



function getLiveView() {
    // Get the first live view. This isn't available till after all the loading.
    if(window.phxView === undefined){
        window.phxView = window.phxSocket.getViewById(Object.keys(liveSocket.views)[0])
    }
    return window.phxView;
}

/*

import React from 'react';
import ReactDOM from 'react-dom';

ReactDOM.render(
    <h1>Hello, world!!</h1>,
    document.getElementById('root')
  );
  

class Cell extends React.Component {
    render() {
        return (
            <div class="Cell">
                <input id="expr-input" name="expression" value="<%= @expression %>"
                class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" type="text"></input>                
            </div>
        )
    }
}

*/

function urlencode(dict) {
    let params = new URLSearchParams();
    return params.toString()
}

function parse_expr(event) {
    event.preventDefault();
    var expr = document.getElementById("expr-input").value;
    var parsed = jsep(expr);
    console.log(parsed);

    var onReply = function(e){
        console.log("Got response back")
        console.log(e);
    }

    var encoded = JSON.stringify(parsed);
    console.log("Encoded")
    console.log(encoded);
    
    getLiveView().pushWithReply("event", {
        type: "form",
        event: "evaluate",
        value: new URLSearchParams({
            "expression": expr,
            "parsed": encoded
        }).toString()
      }, onReply)
  
    /*
    postData("/api/evaluate", parsed)
    .then(json => {
            document.getElementById("result").textContent = json.status + " : " + json.result;
        }
    )
    .catch(error => {
        document.getElementById("result").textContent = "Error : " + error
    });
    */

    return false;
}





(function(){    
    console.log("my code 3")
    var expr_form = document.getElementById("expr-form");
    if(expr_form){
        expr_form.addEventListener("submit", parse_expr, true);
    }
    
})();
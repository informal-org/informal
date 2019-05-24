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

// import LiveSocket from "phoenix_live_view"
// import View from "phoenix_live_view"

// let liveSocket = new LiveSocket("/live")
// liveSocket.connect()

// window.phxSocket = liveSocket;



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

function parse_expr(expr) {
    // console.log(event);
    
    // var expr = event.target.getElementsByClassName("expr-input")[0].value;
    console.log(expr);
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
            "id": cellId,
            "input": expr,
            "parsed": encoded
        }).toString()
      }, onReply)
  
    /*
    */

    return false;
}


import React from "React";
import ReactDOM from "react-dom";


(function(){    
    console.log("my code 4")
    // Should listen to the high level wrapper of this seciton.
    // document.addEventListener("submit", parse_expr, true);
})();

console.log("latest version")

const initialState = {
    "cells": [
        {
            "id": 1,
            "input": "1 + 1"
        },
        {
            "id": 2,
            "input": "2 + 3"
        }
    ]
}

var NEXT_ID = initialState["cells"].length + 1;


class Cell extends React.Component {
    constructor(props) {
        super(props);
        // Required props
        // ID
        // Name (optional)
        // Expression
        // Result (Optional)
        this.state = {
            "input": props.input,
            "cell": props.cell
        }

        // Use arrow function instead to do binding
        // this.changeInput = this.changeInput.bind(this);
        // this.saveCell = this.saveCell.bind(this);    
    }

    changeInput = (event) => {
        this.setState({input: event.target.value});
    }

    saveResult = (response) => {
        console.log(response);
        this.setState({
            output: response.output
        })
    }

    showError = (error) => {
        console.log("Error: " + error);
    }

    saveCell = (event) => {
        console.log("Saving cell");
        event.preventDefault();

        const parsed = jsep(this.state.input);

        postData("/api/evaluate", parsed)
        .then(json => {
                // document.getElementById("result").textContent = json.status + " : " + json.result;
                this.saveResult(json)
            }
        )
        .catch(error => {
            // document.getElementById("result").textContent = "Error : " + error
            this.showError(error);
        });        
    }

    removeCell = (event) => {
        console.log("Removing cell");
        this.props.removeCell(this.props.cell);
    }

    render() {
      return <div className="shadow border rounded py-2 px-3" >
        <form onSubmit={this.saveCell}>
          <input className="form-control bg-gray-200" type="text" onChange={this.changeInput} value={this.state.input}></input>

          <b>{this.state.output}</b>
            <br></br>&nbsp;
          <a className="float-right" onClick={this.removeCell}>Delete</a>
        </form>
      </div>
    }
}

class Module extends React.Component {
    constructor(props) {
        super(props);
        this.state = initialState;
    }

    nextCellId = (state) => {
        return NEXT_ID++;
    }

    addCell = (event) => {
        this.setState((state, props) => ({
            "cells": [...state.cells,
                {
                    "id": this.nextCellId(state),
                    "input": ""
                }]
        }));
    }

    removeCell = (deleteCell) => {
        this.setState( (state, props) => ({
            cells: this.state.cells.filter(cell => cell.id !== deleteCell.id)
        }))
    }

    render() {
        const cells = this.state.cells.map((cell) => 
            <Cell input={cell.input}
                cell={cell}
            key={cell.id} removeCell={this.removeCell} />
        );

        return (
            <div className="Module">
                {cells}

                <button className="btn btn-primary" onClick={this.addCell}>Add Cell</button>
            </div>
        )
    }    
}

ReactDOM.render(
    <Module/>,
    document.getElementById('root')
);

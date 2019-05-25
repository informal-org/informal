// Import CSS so webpack loads it. MiniCssExtractPlugin will split it.
import css from "../css/app.css"
import "phoenix_html"
import "./expr.js"
import React from "React";
import ReactDOM from "react-dom";

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

          <b>{this.state.output} &nbsp; </b>
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

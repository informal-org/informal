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
    cells: [
        {
            id: 1,
            name: "Count",
            input: "1 + 1",
            display: {
                width: 1,
                height: 1
            }
        },
        {
            id: 2,
            name: "Name",
            input: "2 + 3",
            display: {
                width: 1,
                height: 1
            }            
        }
    ],
    focus: {},
    selected: []
}

for(var i = 3; i < 80; i++){
    initialState.cells.push({
        id: i,
        input: "",
        display: {
            width: 1,
            height: 1
        }
    })
}


var NEXT_ID = initialState["cells"].length + 1;
const CELL_MAX_WIDTH = 8;
const CELL_MAX_HEIGHT = 8;

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
            <Cell 
                input={cell.input}
                cell={cell}
                key={cell.id} 
                removeCell={this.removeCell} />
        );

        return (
            <div className="Module">
                {cells}

                <button className="btn btn-primary" onClick={this.addCell}>Add Cell</button>
            </div>
        )
    }    
}

class GridCell extends React.Component {
    constructor(props){
        super(props)
        this.state = props.cell;
    }
    setFocus = (event) => {
        this.props.setFocus(this.props.cell);
    }
    saveCell = (event) => {

    }
    changeInput = (event) => {
        this.setState({input: event.target.value});
    }
    changeName = (event) => {
        this.setState({name: event.target.value});
    }
    render() {
        let cellStyle = {};
        if(this.state.display.width > 1){
            cellStyle["gridColumnEnd"] = "span " + this.state.display.width;
        }
        if(this.state.display.height > 1){
            cellStyle["gridRowEnd"] = "span " + this.state.display.height;
        }
        let className = "Cell";
        if(this.props.isFocused){
            className += " Cell--focused";
        }

        let cellBody = null;
        if(this.props.isFocused){
            cellBody = <form onSubmit={this.saveCell}>

            <input className="Cell-cellName block Cell-cellName--edit" placeholder="Name" type="text" onChange={this.changeName} value={this.state.name}></input> 
            <input className="Cell-cellValue bg-blue-100 block Cell-cellValue--edit" type="text" onChange={this.changeInput} value={this.state.input}></input>
            <b>{this.state.output}5</b>
          </form>
        } else {
            cellBody = <span>
            <div className="Cell-cellName">{this.state.name}</div>
            <div className="Cell-cellValue">{this.state.input}</div>

            </span>
        }

        return <div className={className} style={cellStyle} onClick={this.setFocus}>
            {cellBody}
        </div>
    }
}

class ActionBar extends React.Component {
    constructor(props) {
        super(props);
    }
    incWidth = () => {
        this.props.incWidth();
    }
    decWidth = () => {
        this.props.decWidth();
    }
    incHeight = () => {
        this.props.incHeight();
    }
    decHeight = () => {
        this.props.decHeight();
    }    
    render() {
        return <div className="ActionBar">
            <div className="inline-block">
                <div className="ActionBar-action" onClick={this.decWidth} >
                    -
                </div>
                <div className="px-3 py-2 inline-block">
                Width
                </div>
                <div className="ActionBar-action" onClick={this.incWidth} >
                    +
                </div>
            </div>

            <div className="inline-block">
                <div className="ActionBar-action" onClick={this.decHeight} >
                    -
                </div>
                <div className="px-3 py-2 inline-block">
                Height
                </div>
                <div className="ActionBar-action" onClick={this.incHeight} >
                    +
                </div>
            </div>
            
        </div>
    }
}

class Grid extends React.Component {
    constructor(props) {
        super(props);
        this.state = initialState;
    }
    setFocus = (cell) => {
        this.setState((state, props) => ({
            focus: cell
        }));
    }
    clearFocus = () => {
        this.setState((state, props) => ({
            focus: {}
        }));        
    }
    incWidth = () => {
        this.setState((state, props) => {
            let newFocus = state.focus;
            if(newFocus && newFocus.display.width < CELL_MAX_WIDTH){
                newFocus.display.width += 1;
            }
            return {
                focus: newFocus
            }
        });
    }
    decWidth = () => {
        this.setState((state, props) => {
            let newFocus = state.focus;
            if(newFocus && newFocus.display.width > 1){
                newFocus.display.width -= 1;
            }
            return {
                focus: newFocus
            }
        });
    }
    incHeight = () => {
        this.setState((state, props) => {
            let newFocus = state.focus;
            if(newFocus && newFocus.display.height < CELL_MAX_HEIGHT){
                newFocus.display.height += 1;
            }
            return {
                focus: newFocus
            }
        });
    }
    decHeight = () => {
        this.setState((state, props) => {
            let newFocus = state.focus;
            if(newFocus && newFocus.display.height > 1){
                newFocus.display.height -= 1;
            }
            return {
                focus: newFocus
            }
        });
    }

    render() {
        const cells = this.state.cells.map((cell) => 
            <GridCell 
                cell={cell}
                isFocused={this.state.focus.id == cell.id}
                key={cell.id}
                setFocus={this.setFocus}
                />
        )
        
        return <div>
            <ActionBar 
            incWidth={this.incWidth}
            decWidth={this.decWidth}
            incHeight={this.incHeight}
            decHeight={this.decHeight}
            ></ActionBar>
        
            <div className="Grid">
                {cells}
            </div>

        </div>
    }
}

ReactDOM.render(
    <Grid/>,
    document.getElementById('root')
);

// Import CSS so webpack loads it. MiniCssExtractPlugin will split it.
import css from "../css/app.css"
import "phoenix_html"
import parseExpr from "./expr.js"
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
            type: "cell",
            name: "Count",
            input: "1 + 1",
            display: {
                width: 1,
                height: 1
            }
        },
        {
            id: 2,
            type: "cell",
            name: "Name",
            input: "2 + 3",
            display: {
                width: 1,
                height: 1
            }            
        },
    ],
    focus: null,
    selected: []
}

for(var i = 3; i < 80; i++){
    initialState.cells.push({
        id: i,
        type: "cell",
        name: "",
        input: i,
        display: {
            width: 1,
            height: 1
        }
    },
)
}


// Sentinels will provide us a fast data structure without needing an element per item.

var NEXT_ID = initialState["cells"].length + 1;
const CELL_MAX_WIDTH = 8;
const CELL_MAX_HEIGHT = 8;

// A computed structure to keep track of where things appear.

function getGridDisplay(cells){
    // A declarative computation of where cells would appear in a grid according to the subset of the 
    // css grid flow rules that we use.
    // Index: [x][y]
    var grid = new Array(CELL_MAX_WIDTH);
    // Pre-fill array. Might be possible to do this along with the bottom steps, but makes it complex.

    for(var x = 0; x < CELL_MAX_WIDTH; x++){
        // Over-provision. I assume this is enough?
        gridRows.push(new Array(cells.length))
    }

    var nextFreeX = 0;
    var nextFreeY = 0;
    var currentRow = [];
    for(var i = 0; i < cells.length; i++){
        const width = cells[i].display.width;
        const height = cells[i].display.height;

        // Find the next open spot where this would fit.
        // Assume: grid-auto-flow: row. If dense, this is more complex and 
        // the UI can also shift around a lot.
        let found = false;
        var searchY = nextFreeY;
        var searchX = nextFreeX;
        while(!found){
            // Check if width up to this length is free.
            grid[searchX][searchY]

        }
        
    }
}



class ActionBar extends React.Component {
    constructor(props) {
        super(props);
    }
    nextCellId = (state) => {
        return NEXT_ID++;
    }

    addCell = (event) => {
        // this.setState((state, props) => ({
        //     "cells": [...state.cells,
        //         {
        //             "id": this.nextCellId(state),
        //             "input": ""
        //         }]
        // }));
    }

    removeCell = (deleteCell) => {
        // this.setState( (state, props) => ({
        //     cells: this.state.cells.filter(cell => cell.id !== deleteCell.id)
        // }))
    }

    render() {
        return <div className="ActionBar">
            <div className="inline-block">
                <div className="ActionBar-action" onClick={this.props.decWidth} >
                    -
                </div>
                <div className="px-3 py-2 inline-block">
                Width
                </div>
                <div className="ActionBar-action" onClick={this.props.incWidth} >
                    +
                </div>
            </div>

            <div className="inline-block">
                <div className="ActionBar-action" onClick={this.props.decHeight} >
                    -
                </div>
                <div className="px-3 py-2 inline-block">
                Height
                </div>
                <div className="ActionBar-action" onClick={this.props.incHeight} >
                    +
                </div>
            </div>
        </div>
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

        const parsed = parseExpr(this.state.input);

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
    changeInput = (event) => {
        this.setState({input: event.target.value});
    }
    changeName = (event) => {
        this.setState({name: event.target.value});
    }
    render() {
        let className = "Cell draggable";
        className += " Cell--width" + this.state.display.width;
        className += " Cell--height" + this.state.display.height;
        if(this.props.isFocused){
            className += " Cell--focused";
        }
        if(this.props.isError) {
            className += " Cell--error";
        }

        let cellBody = null;
        if(this.props.isFocused){
            cellBody = <form onSubmit={this.saveCell}>
            <input className="Cell-cellName block Cell-cellName--edit" placeholder="Name" type="text" onChange={this.changeName} value={this.state.name}></input> 
            <input className="Cell-cellValue bg-blue-100 block Cell-cellValue--edit" type="text" onChange={this.changeInput} value={this.state.input}></input>
            <span className="Cell-cellResult inline-block">
                {this.state.output ? this.state.output : " "}        
            </span>
            <input type="submit" className="hidden"/>
          </form>
        } else {
            cellBody = <span>
            <div className="Cell-cellName">{this.state.name}</div>
            <div className="Cell-cellValue">{this.state.input}</div>
            </span>
        }

        return <div className={className} 
        onClick={this.setFocus}
        onDragStart={this.props.onDragStart}
        onDragOver={this.props.onDragOver}
        onDrop={this.props.onDrop}
        draggable={true}>
            {cellBody}
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
            focus: null
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

	onDragStart = (event, cell) => {
        let cellPos = this.state.cells.indexOf(cell);
    	event.dataTransfer.setData("cellIdx", cellPos);
	}
	onDragOver = (event) => {
        // console.log("Drag over")
        event.preventDefault();
	}

	onDrop = (event, targetCell) => {
        let fromIndex = event.dataTransfer.getData("cellIdx");
        if(fromIndex){
            this.setState((state, props) => {
                let toIndex = state.cells.indexOf(targetCell);
                console.log(targetCell);
                console.log(fromIndex);
                console.log(toIndex);
                if(fromIndex !== -1 && toIndex !== -1){
                    let fromCell = state.cells[fromIndex];
                    state.cells.splice(fromIndex, 1);   // Remove cell
                    state.cells.splice(toIndex, 0, fromCell);    // Insert into new pos    
                }
    
                return {
                    cells: state.cells
                }
            })    
        }


	    // let taskName = event.dataTransfer.getData("taskName");
	    // let tasks = this.state.tasks.filter((task) => {
	    //     if (task.taskName == taskName) {
	    //         task.type = cat;
	    //     }
	    //     return task;
	    // });

	    // this.setState({
	    //     ...this.state,
	    //     tasks
	    // });
	}

    render() {
        const cells = this.state.cells.map((cell) => {
            return <GridCell 
                cell={cell}
                isFocused={this.state.focus === cell}
                isError={false}
                key={cell.id}
                setFocus={this.setFocus}
                onDragStart = {(event) => this.onDragStart(event, cell)}
                
                onDragOver={(event)=>this.onDragOver(event, cell)}
                onDrop={(event)=>{this.onDrop(event, cell)}}
                />
        })
        
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

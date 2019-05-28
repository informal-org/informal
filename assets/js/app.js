// Import CSS so webpack loads it. MiniCssExtractPlugin will split it.
import css from "../css/app.css"
import "phoenix_html"
import parseExpr from "./expr.js"
import computeGridPositions from "./grid.js"
import React from "React";
import ReactDOM from "react-dom";
import { connect } from 'react-redux'

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
            id: "01",
            type: "cell",
            name: "Count",
            input: "1 + 1",
            display: {
                width: 1,
                height: 1
            }
        },
        {
            id: "02",
            type: "cell",
            name: "Name",
            input: "2 + 3",
            display: {
                width: 1,
                height: 1
            }            
        },
    ],
    focus: null
}

for(var i = 3; i < 80; i++){
    let id = "";
    if(i < 10) {
        id += "0";
    }
    initialState.cells.push({
        id: id + i,
        type: "cell",
        name: "",
        input: "",
        display: {
            width: 1,
            height: 1
        }
    })
}

import { configureStore, createReducer, createAction, createSlice } from 'redux-starter-kit'
import { Provider } from 'react-redux'

// const setFocus = createAction("SET_FOCUS");
const saveCell = createAction("SAVE_CELL");
const changeCellInput = createAction("CHANGE_CELL_INPUT");
const changeCellName = createAction("CHANGE_CELL_NAME");
const incWidth = createAction("INC_WIDTH");
const decWidth = createAction("DEC_WIDTH");
const incHeight = createAction("INC_HEIGHT");
const decHeight = createAction("DEC_HEIGHT");
const dropCell = createAction("DROP_CELL");

const cellsSlice = createSlice({
    slice: 'cells',
    initialState: initialState.cells,
    reducers: {
      saveCell(state, action) {
          console.log("Save cell")
      }
    }
})

const focusSlice = createSlice({
    slice: 'focus',
    initialState: {},
    reducers: {
        setFocus(state, action) {
            console.log("Setting focus");
        }
    }
})

const cellsReducer = cellsSlice.reducer;
const focusReducer = focusSlice.reducer;
const store = configureStore({
  reducer: {
    cellsReducer,
    focusReducer
  }
})

const mapStateToProps = (state /*, ownProps*/) => {
    return {
      cells: state.cells
    }
  }

const setFocus = focusSlice.actions.setFocus;
// const mapDispatchToProps = dispatch => ({ setFocus: () => dispatch(setFocus()) })
const mapDispatchToProps = {setFocus}
  

function parseEverything(cells) {
    let data = {}
    let activeCells = cells.filter((cell) => {
        // TODO: Also need to check for if any dependent cells. 
        // So that it's valid to have cells with space
        return cell.input.trim() !== ""
    }).map((cell) => {
        return {
            id: cell.id,
            input: cell.input,
            parsed: parseExpr(cell.input)
        }
    })
    data.body = {}
    activeCells.forEach((cell) => {
        data.body[cell.id] = cell
    })
    return data
}

// Sentinels will provide us a fast data structure without needing an element per item.
var NEXT_ID = initialState["cells"].length + 1;
const CELL_MAX_WIDTH = 7;
const CELL_MAX_HEIGHT = 8;

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
        console.log(this.state.input);
        if(this.state.input.trim() === ""){
            this.setState({output: ""})
            return
        }

        // const parsed = parseExpr(this.state.input);

        // postData("/api/evaluate", parsed)
        // .then(json => {
        //         // document.getElementById("result").textContent = json.status + " : " + json.result;
        //         this.saveResult(json)
        //     }
        // )
        // .catch(error => {
        //     // document.getElementById("result").textContent = "Error : " + error
        //     this.showError(error);
        // });

        this.props.recomputeCell(this.state.cell)
    }
    changeInput = (event) => {
        this.setState({input: event.target.value});
    }
    changeName = (event) => {
        this.setState({name: event.target.value});
    }
    formatOutput = () => {
        if(this.state.output === undefined){
            return " "
        }
        else if(this.state.output === true) {
            return "True"
        } 
        else if(this.state.output === false) {
            return "False"
        } else {
            return "" + this.state.output
        }
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
                <i className="fas fa-expand float-right text-gray-700 maximize"></i>
            <input className="Cell-cellName block Cell-cellName--edit" placeholder="Name" type="text" onChange={this.changeName} value={this.state.name}></input> 
            <input className="Cell-cellValue bg-blue-100 block Cell-cellValue--edit" type="text" onChange={this.changeInput} value={this.state.input}></input>
            <span className="Cell-cellResult inline-block">
                {this.formatOutput()}
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

function modifySize(cell, dimension, min, max, fn) {
    console.log("modify " + cell);
    if(cell){
        let newSize = fn(cell.display[dimension])
        if(newSize >= min && newSize <= max){
            cell.display[dimension] = newSize;
        }
    }
    return cell
}

function inc(x) {
    console.log("inc " + x)
    return x + 1
}

function dec(x) {
    return x - 1
}


class Grid extends React.Component {
    constructor(props) {
        super(props);
        this.state = initialState;
        // this.recomputeCells()
    }
    setFocus = (cell) => {
        // this.setState((state, props) => ({
        //     focus: cell
        // }));
        // console.log("Grid set focus");
        this.props.setFocus()
    }
    clearFocus = () => {
        this.setState((state, props) => ({
            focus: null
        }));        
    }
    recomputeCells = () => {
        var allParsed = parseEverything(this.state.cells)
        this.state.cells.forEach((cell) => {
            console.log(cell.input);
        })

        postData("/api/evaluate", allParsed)
        .then(json => {
            // Find the cells and save the value.
            let results = json["body"];
            this.setState((state, props) => {
                let cells = state.cells
                for(var i = 0; i < cells.length; i++){
                    let cell = cells[i];
                    if(cell.id in results){
                        cell.output = results[cell.id].output
                    }
                }
                return {
                    cells: cells
                }
            })
            
            // let results = json.map((cell))
            // this.setState(cells, json)
        })
        .catch(error => {
            // document.getElementById("result").textContent = "Error : " + error
            console.log("Error")
            console.log(error);
        });
    }
    recomputeCell = (cell) => {
        this.recomputeCells()
    }
    incWidth = () => {
        this.setState((state, props) => {
            return {
                focus: modifySize(state.focus, "width", 1, CELL_MAX_WIDTH, inc)
            }
        });
    }
    decWidth = () => {
        this.setState((state, props) => {
            return {
                focus: modifySize(state.focus, "width", 1, CELL_MAX_WIDTH, dec)
            }
        });
    }
    incHeight = () => {
        this.setState((state, props) => {
            return {
                focus: modifySize(state.focus, "height", 1, CELL_MAX_HEIGHT, inc)
            }
        });
    }
    decHeight = () => {
        this.setState((state, props) => {
            return {
                focus: modifySize(state.focus, "height", 1, CELL_MAX_HEIGHT, dec)
            }
        });
    }
	onDragStart = (event, cell) => {
        let cellPos = this.state.cells.indexOf(cell);
    	event.dataTransfer.setData("cellIdx", cellPos);
	}
	onDragOver = (event) => {
        event.preventDefault();
	}
	onDrop = (event, targetCell) => {
        // Right now we only support drag and drop on top of other cells
        // not over empty space.
        let fromIndex = event.dataTransfer.getData("cellIdx");
        if(fromIndex){
            this.setState((state, props) => {
                let toIndex = state.cells.indexOf(targetCell);

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
	}

    render() {
        const cells = this.state.cells.map((cell) => {
            return <GridCell 
                cell={cell}
                isFocused={this.state.focus === cell}
                isError={false}
                key={cell.id}
                setFocus={this.setFocus}
                recomputeCell = {this.recomputeCell}
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

const ConnectedGrid = connect(
    mapStateToProps,
    mapDispatchToProps
  )(Grid)
 
ReactDOM.render(
    <Provider store={store}>
        <ConnectedGrid/>
    </Provider>,
    document.getElementById('root')
);

window.store = store;

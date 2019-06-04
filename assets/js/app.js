// Import CSS so webpack loads it. MiniCssExtractPlugin will split it.
import css from "../css/app.css"
import "phoenix_html"
import parseExpr from "./expr.js"
import computeGridPositions from "./grid.js"
import React from "React";
import ReactDOM from "react-dom";
import { connect } from 'react-redux'
import {listToMap, apiPost} from './utils.js'
import {modifySize, parseEverything} from './controller.js'
import { configureStore, createReducer, createAction, createSlice } from 'redux-starter-kit'
import { Provider } from 'react-redux'
import {original} from "immer"

const initialState = {
    cells: {
        byId: {
            "01": {
                id: "01",
                type: "cell",
                name: "Count",
                input: "1 + 1",
                width: 1,
                height: 1
            },
            "02": {
                id: "02",
                type: "cell",
                name: "Name",
                input: "2 + 3",
                width: 1,
                height: 1            
            }
        },
        allIds: ["01", "02"],
    },
    focus: null
}

for(var i = 3; i < 80; i++){
    let id = "";
    if(i < 10) {
        id += "0";
    }
    id = id + i
    initialState.cells.byId[id] = {
        id: id,
        type: "cell",
        name: "",
        input: "",
        width: 1,
        height: 1
    }
    initialState.cells.allIds.push(id);
}


const reEvaluate = (param) => {
    console.log("Re-evaluating");
    return (dispatch) => {
        console.log("inner function");
        // let parsed = parseEverything(state.byId)
        // console.log("Parsed")
        // apiPost("/api/evaluate", parsed)
        // .then(json => {
        //     console.log("Fetching")
        //     // Find the cells and save the value.
        //     let results = json["body"];
        //     dispatch(saveOutput({
        //         'status': success,
        //         'response': results
        //     }))
        //     // this.setState((state, props) => {
        //     //     let cells = state.cells
        //     //     for(var i = 0; i < cells.length; i++){
        //     //         let cell = cells[i];
        //     //         if(cell.id in results){
        //     //             cell.output = results[cell.id].output
        //     //         }
        //     //     }
        //     //     return {
        //     //         cells: cells
        //     //     }
        //     // })
            
        //     // let results = json.map((cell))
        //     // this.setState(cells, json)
        // })
        // .catch(error => {
        //     // document.getElementById("result").textContent = "Error : " + error
        //     console.log("Error")
        //     console.log(error);
        // });                
    }
}


const cellsSlice = createSlice({
    slice: 'cells',
    initialState: initialState.cells,
    reducers: {
        setInput: (state, action) => {
            state.byId[action.payload.id].input = action.payload.input;
        },
        saveOutput: (state, action) => {
            console.log("Save output");
            console.log(action);
        },
        incWidth: (state, action) => {
            modifySize(state.byId[action.payload.id], "width", 1, CELL_MAX_WIDTH, action.payload.amt);
        }, 
        incHeight: (state, action) => {
            modifySize(state.byId[action.payload.id], "height", 1, CELL_MAX_HEIGHT, action.payload.amt);
        },
        dragCell: (state, action) => {
            // Right now we only support drag and drop on top of other cells
            // not over empty space.
            let fromIndex = state.allIds.indexOf(action.payload.from);
            let toIndex = state.allIds.indexOf(action.payload.to);
            if(fromIndex !== undefined && toIndex !== undefined && fromIndex !== -1 && toIndex !== -1){
                state.allIds.splice(fromIndex, 1);   // Remove cell
                state.allIds.splice(toIndex, 0, action.payload.from); // Insert into new pos
            }
        }

    }
})


const focusSlice = createSlice({
    slice: 'focus',
    initialState: {},
    reducers: {
        setFocus: (state, action) => {
            return action.payload
        }
    }
})

const setInput = cellsSlice.actions.setInput;
// const reEvaluate = cellsSlice.actions.reEvaluate;
const incWidth = cellsSlice.actions.incWidth;
const incHeight = cellsSlice.actions.incHeight;
const dragCell = cellsSlice.actions.dragCell;
const setFocus = focusSlice.actions.setFocus;

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
        cells: state.cellsReducer.allIds.map((id) => state.cellsReducer.byId[id]),
        focus: state.focusReducer
    }
}

const mapDispatchToProps = {setFocus, setInput, reEvaluate, incWidth, incHeight, dragCell}

// Sentinels will provide us a fast data structure without needing an element per item.
var NEXT_ID = initialState["cells"].length + 1;
const CELL_MAX_WIDTH = 7;
const CELL_MAX_HEIGHT = 8;

class ActionBar extends React.Component {
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
        this.state = {
            input: props.cell.input,
            name: props.cell.name
        }
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
        // TODO: Port over
        // if(this.state.input.trim() === ""){
        //     this.setState({output: ""})
        //     return
        // }
        this.props.setInput({id: this.props.cell.id, input: this.state.input})
        this.props.reEvaluate()

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

        // this.props.recomputeCell(this.state.cell)
    }
    changeInput = (event) => {
        this.setState({input: event.target.value});
    }
    changeName = (event) => {
        this.setState({name: event.target.value});
    }
    formatOutput = () => {
        if(this.props.output === undefined){
            return " "
        }
        else if(this.props.output === true) {
            return "True"
        } 
        else if(this.props.output === false) {
            return "False"
        } else {
            return "" + this.props.output
        }
    }
    render() {
        let className = "Cell draggable";
        className += " Cell--width" + this.props.cell.width;
        className += " Cell--height" + this.props.cell.height;
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


class Grid extends React.Component {
    constructor(props) {
        super(props);
        console.log(this.props);
        console.log("store");
        console.log(store)
        // this.state = initialState;
        // this.recomputeCells()
    }
    recomputeCells = () => {
        var allParsed = parseEverything(this.state.cells)
        this.state.cells.forEach((cell) => {
            console.log(cell.input);
        })

        apiPost("/api/evaluate", allParsed)
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
        if(this.props.focus){
            this.props.incWidth({id: this.props.focus.id, amt: 1})
        }
    }
    decWidth = () => {
        if(this.props.focus){
            this.props.incWidth({id: this.props.focus.id, amt: -1})
        }
    }
    incHeight = () => {
        if(this.props.focus){
            this.props.incHeight({id: this.props.focus.id, amt: 1})
        }
    }
    decHeight = () => {
        if(this.props.focus){
            this.props.incHeight({id: this.props.focus.id, amt: -1})
        }
    }
	onDragStart = (event, cell) => {
    	event.dataTransfer.setData("fromCell", cell.id);
	}
	onDragOver = (event) => {
        event.preventDefault();
	}
	onDrop = (event, targetCell) => {
        this.props.dragCell({
            from: event.dataTransfer.getData("fromCell"),
            to: targetCell.id
        })
	}

    render() {
        const cells = this.props.cells.map((cell) => {
            return <GridCell 
                cell={cell}
                isFocused={this.props.focus === cell}
                isError={false}
                key={cell.id}
                setFocus={this.props.setFocus}
                setInput={this.props.setInput}
                reEvaluate={this.props.reEvaluate}
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

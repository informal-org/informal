// Import CSS so webpack loads it. MiniCssExtractPlugin will split it.
import css from "../css/app.css"
import "phoenix_html"
import computeGridPositions from "./grid.js"
import React from "React";
import ReactDOM from "react-dom";
import { connect } from 'react-redux'
import { apiPost } from './utils.js'
import { modifySize, parseEverything } from './controller.js'
import { configureStore, createSlice } from 'redux-starter-kit'
import { Provider } from 'react-redux'

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
        focus: null  // ID of the element selected
    }
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



const cellsSlice = createSlice({
    slice: 'cells',
    initialState: initialState.cells,
    reducers: {
        setInput: (state, action) => {
            state.byId[action.payload.id].input = action.payload.input;
        },
        saveOutput: (state, action) => {
            let status = action.payload.status;
            let response = action.payload.response;
            const ids = Object.keys(response);
            ids.forEach((id) => {
                let responseCell = response[id];
                let stateCell = state.byId[id];
                stateCell.output = responseCell.output;
            });
        },
        incWidth: (state, action) => {
            modifySize(state.byId[action.payload.id], "width", 1, CELL_MAX_WIDTH, action.payload.amt);
        }, 
        incHeight: (state, action) => {
            modifySize(state.byId[action.payload.id], "height", 1, CELL_MAX_HEIGHT, action.payload.amt);
        },
        setFocus: (state, action) => {
            state.focus = action.payload
        },
        moveFocus: (state, action) => {
            let currentIndex = state.allIds.indexOf(state.focus);
            if(currentIndex !== -1){
                let newIndex = currentIndex + action.payload;
                if(newIndex >= 0 && newIndex <= state.allIds.length){
                    state.focus = state.allIds[newIndex];
                }
            }
        }
    }
})


const setInput = cellsSlice.actions.setInput;
const saveOutput = cellsSlice.actions.saveOutput;
// const reEvaluate = cellsSlice.actions.reEvaluate;
const incWidth = cellsSlice.actions.incWidth;
const incHeight = cellsSlice.actions.incHeight;
const setFocus = cellsSlice.actions.setFocus;
const moveFocus = cellsSlice.actions.moveFocus;



const reEvaluate = () => {
    return (dispatch, getState) => {
        const state = getState();
        console.log("State s");
        console.log(state);
        let parsed = parseEverything(state.cellsReducer.byId)
        console.log("Parsed")
        apiPost("/api/evaluate", parsed)
        .then(json => {
            console.log("Fetching")
            // Find the cells and save the value.
            let results = json["body"];
            dispatch(saveOutput({
                'status': true,
                'response': results
            }))
        })
        .catch(error => {
            // document.getElementById("result").textContent = "Error : " + error
            console.log("Error")
            console.log(error);
            // TODO error state
        });
    }
}

const cellsReducer = cellsSlice.reducer;
const store = configureStore({
  reducer: {
    cellsReducer
  }
})

const mapStateToProps = (state /*, ownProps*/) => {
    return {
        cells: state.cellsReducer.allIds.map((id) => state.cellsReducer.byId[id]),
        focus: state.cellsReducer.focus
    }
}

const mapDispatchToProps = {setFocus, setInput, reEvaluate, incWidth, incHeight, moveFocus}

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
        this.props.setFocus(this.props.cell.id);
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
        let output = this.props.cell.output;
        if(output === undefined){
            return " "
        }
        else if(output === true) {
            return "True"
        } 
        else if(output === false) {
            return "False"
        } else {
            return "" + output
        }
    }
    onKeyDown = (event) => {
        // Only process events that happen directly on the outer div, not in inner inputs, etc.
        let isCellTarget = event.target.dataset["cell"] === this.props.cell.id;
        if(isCellTarget){
            // Deferred - up = 38, down=40. Requires more complex calculation to get grid pos.
            if (event.keyCode == 37) {
                // Left arrow
                this.props.moveFocus(-1);
            }
            else if (event.keyCode == 39) {
                // Right arrow
                this.props.moveFocus(1);
            } else if (event.keyCode == 27) {
                // ESC with cell selected. Clear focus.
                this.props.setFocus(null);
            }
        } else if (event.keyCode == 27) {
            // ESC
            // De-select input and set focus back on cells
            event.target.blur();
            event.target.closest(".Cell").focus();
        }
    
    }
    render() {
        let className = "Cell";
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
            <div className="Cell-cellValue">{this.formatOutput()}</div>
            </span>
        }

        return <div className={className} 
        onClick={this.setFocus} 
        onKeyDown={this.onKeyDown}
        tabIndex="0" data-cell={this.props.cell.id}>
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
            this.props.incWidth({id: this.props.focus, amt: 1})
        }
    }
    decWidth = () => {
        if(this.props.focus){
            this.props.incWidth({id: this.props.focus, amt: -1})
        }
    }
    incHeight = () => {
        if(this.props.focus){
            this.props.incHeight({id: this.props.focus, amt: 1})
        }
    }
    decHeight = () => {
        if(this.props.focus){
            this.props.incHeight({id: this.props.focus, amt: -1})
        }
    }
    isFocused = (cell) => {
        return this.props.focus === cell.id;
    }
    render() {
        const cells = this.props.cells.map((cell) => {
            return <GridCell 
                cell={cell}
                isFocused={this.isFocused(cell)}
                isError={false}
                key={cell.id}
                setFocus={this.props.setFocus}
                moveFocus={this.props.moveFocus}
                setInput={this.props.setInput}
                reEvaluate={this.props.reEvaluate}
                recomputeCell = {this.recomputeCell}
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

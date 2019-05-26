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
        let className = "Cell";
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
            <span className="Cell-cellResult inline-block">{this.state.output ? this.state.output : " "}
            
            
            m Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.

Why do we use it?
It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English. Many desktop publishing packages and web page editors now use Lorem Ipsum as their default model text, and a search for 'lorem ipsum' will uncover many web sites still in their infancy. Various versions have evolved over the years, sometimes by accident, sometimes on purpose (injected humour and the like).


Where does it come from?
Contrary to popular belief, Lorem Ipsum is not simply random text. It has roots in a piece of classical Latin literature from 45 BC, making it over 2000 years old. Richard McClintock, a Latin professor at Hampden-Sydney College in Virginia, looked up one of the more obscure Latin words, consectetur, from a Lorem Ipsum passage, and going through the cites of the word in classical literature, discovered the undoubtable source. Lorem Ipsum comes from sections 1.10.32 and 1.10.33 of "de Finibus Bonorum et Malorum" (The Extremes of Good and Evil) by Cicero, writ
            
            </span>
            <input type="submit" className="hidden"/>
          </form>
        } else {
            cellBody = <span>
            <div className="Cell-cellName">{this.state.name}</div>
            <div className="Cell-cellValue">{this.state.input}</div>
            </span>
        }

        return <div className={className} onClick={this.setFocus}>
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
                isError={false}
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

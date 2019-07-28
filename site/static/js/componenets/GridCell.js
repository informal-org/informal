import React from "react";
import ReactDOM from "react-dom";
import AbstractBaseCell from "./AbstractBaseCell.js"
import { cellGet, formatCellOutput } from "../utils.js"

export default class GridCell extends AbstractBaseCell {
    constructor(props){
        super(props)
        this.state = {
            input: cellGet(props.cell, "input"),
            name: cellGet(props.cell, "name")
        }
    }

    saveCell = (event) => {
        event.preventDefault();
        // TODO: Port over
        // if(this.state.input.trim() === ""){
        //     this.setState({output: ""})
        //     return
        // }
        this.props.setInput({id: this.props.cell.id, input: this.state.input})
        this.props.reEvaluate();

        this.clearFocus();
    }

    render() {
        let className = "Cell";
        className += " Cell--width" + cellGet(this.props.cell, "width", 1);
        className += " Cell--height" + cellGet(this.props.cell, "height", 1);
        if(this.props.isFocused){
            className += " Cell--focused";
        }
        let cellResults = null;
        let error = cellGet(this.props.cell, "error")
        if(error) {
            className += " Cell--error";
            cellResults = <div className="Cell-cellError">{error}</div>
        } else {
            cellResults = <div className="Cell-cellValue">{this.formatOutput()}</div>
        }

        let cellBody = null;
        if(this.props.isFocused){
            cellBody = <form onSubmit={this.saveCell}>
            <i className="fas fa-expand float-right text-gray-700 maximize"></i>
            <input className="Cell-cellName block Cell-cellName--edit" placeholder="Name" type="text" onChange={this.changeName} value={this.state.name}></input> 
            <input className="Cell-cellValue bg-blue-100 block Cell-cellValue--edit" type="text" onChange={this.changeInput} value={this.state.input}></input>
            <input type="submit" className="hidden"/>
          </form>
        } else {
            cellBody = <span>
            <div className="Cell-cellName">{this.state.name}</div>
            {cellResults}
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

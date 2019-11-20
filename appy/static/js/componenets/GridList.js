import React from "react";
import AbstractBaseCell from "./AbstractBaseCell.js"
import GridCell from "./GridCell.js"
import { cellGet, formatCellOutput } from "../utils.js"

export default class GridList extends AbstractBaseCell {
    constructor(props){
        super(props)
        this.state = {
            name: cellGet(props.cell, "name")
        }
    }

    saveCell = (event) => {
        event.preventDefault();
        this.props.reEvaluate();
        this.clearFocus();
    }

    formatOutput = () => {
        return formatCellOutput(this.props.cell);
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
        // TODO: Error handling of cells

        // if(error) {
        //     className += " Cell--error";
        //     cellResults = <div className="Cell-cellError">{error}</div>
        // } else {
        //     cellResults = <div className="Cell-cellValue">{this.formatOutput()}</div>
        // }

        // Todo: Focused state?
        let values = this.props.values.map((cell) => {
            let isFocused = this.props.focus === cell.id;
            // TODO - support of arbritrary cell type.
            return <GridCell 
                cell={cell}
                isFocused={isFocused}
                isError={false}
                key={cell.id}
                setModified={this.props.setModified}
                setFocus={this.props.setFocus}
                moveFocus={this.props.moveFocus}
                setInput={this.props.setInput}
                setName={this.props.setName}
                reEvaluate={this.props.reEvaluate}
                recomputeCell = {this.recomputeCell}
                />
        })


        let cellBody = null;
        if(this.props.isFocused){
            cellBody = <form onSubmit={this.saveCell}>
            <i className="fas fa-expand float-right text-gray-700 maximize"></i>
            <input className="Cell-cellName block Cell-cellName--edit" placeholder="Name" type="text" onChange={this.changeName} value={this.state.name}></input> 
            <input type="submit" className="hidden"/>
          </form>
        } else {
            cellBody = <span>
            <div className="Cell-cellName">{this.state.name}</div>
            {values}
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

import React from "react";
import ReactDOM from "react-dom";
import AbstractBaseCell from "./AbstractBaseCell.js"
import { cellGet, formatCellOutput } from "../utils"

import Editor from 'react-simple-code-editor';
import CellParam from "./CellParam.js"
import CellValue from "./CellValue"
import { highlight, languages } from 'prismjs/components/prism-core';
// import 'prismjs/components/prism-clike';
// import 'prismjs/components/prism-javascript';
import './prism-aa';

import { addParam, addRow } from "../store.js"

export default class GridCell extends AbstractBaseCell {
    constructor(props){
        super(props)
        this.state = {
            input: cellGet(props.cell, "expr"),
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

    addParam = () => {
        window.store.dispatch(addParam({
            id: this.props.cell.id
        }))
    }

    addRow = () => {
        window.store.dispatch(addRow({
            id: this.props.cell.id
        }))
    }

    renderParams() {
        // var params = [];
        // for(var i = 0; i < this.props.cell.params.length; i++) {
        //     var elem = <CellParam cell={this.props.cell} param_index={i} key={"param" + i}/>
        //     params.push(elem)
        // }

        // return <div className="Cell-inputs col-sm-2">
        //     <label>Parameters: </label>
        //     {params}
        //     <div className="btn btn-placeholder" onClick={this.addParam}>+ Add Input</div>
        // </div>


        if(this.props.cell.params.length > 0) {
            return <div className="col-sm-4 inline-block">
                <label>Input Parameters: </label>
            </div>
        }
        else {
            return <span></span>
        }

    }

    render() {
        let rendered;
        let className = "Cell";

        if(this.props.isFocused){
            className += " Cell--focused";
            if(this.props.isOpen) {
                className += " Cell--open"
            }
        }
        let cellResults = null;
        let error = cellGet(this.props.cell, "error")
        if(error) {
            className += " Cell--error";
            cellResults = <div className="Cell-cellError">{"" + error}</div>
        } else {
            cellResults = <CellValue value={this.props.cell.value}></CellValue>
        }

        if(this.props.isFocused && this.props.isOpen){
            let cell_id = this.props.cell.id;
            setTimeout(() => {
                // If the current cell is not focused when open, set focus
                let currentFocus = document.activeElement;
                let targetFocus = "Cell_" + cell_id;
                let isSubFocus = currentFocus.closest("#" + targetFocus);
                if(!isSubFocus) {
                    document.getElementById(targetFocus).focus();
                }
                
            }, 100)
            return <div className={className}
                id={"Cell_" + cell_id}
                onClick={this.setFocus}
                onKeyDown={this.onKeyDown}
                autoFocus
                tabIndex="0" data-cell={cell_id}>

            <form onSubmit={this.saveCell} className="Cell-edit container-fluid">
            <i className="fas fa-expand float-right text-gray-700 maximize"></i>

            <div className="row">
                <div className="col-sm-2 inline-block Cell-nameHeader">
                    <label htmlFor="variable_name">Name: </label>
                    <input id="variable_name" 
                    className="inline-block Cell-cellName Cell-cellName--edit" 
                    placeholder="Name" 
                    type="text" 
                    onChange={this.changeName} 
                    value={this.state.name}
                    autoComplete="off"></input> 
                </div>

                {this.renderParams()}
                

                <div className="Cell-outputs col-sm-10">
                    {/* <input className="Cell-cellValue bg-blue-100 block Cell-cellValue--edit" placeholder="Value" type="text" onChange={this.changeInput} value={this.state.input}></input> */}

                    <label>Value: </label>
                    <ul className="list-group col-sm-12">
                        <li className="list-group-item">
                            <Editor
                                value={this.state.input}
                                onValueChange={this.changeInput}
                                highlight={code => highlight(code, languages.aa)}
                                padding={10}
                                style={{
                                fontFamily: '"Fira code", "Fira Mono", monospace',
                                fontSize: 12,
                                }}
                            />
                        </li>
                        {/* <li className="list-group-item btn btn-placeholder w-full" onClick={this.addRow}>+ Add row </li> */}
                    </ul>

                </div>

            </div>

            <div className="row">
                

            </div>

            <input type="submit" className="hidden"/>
          </form>
          </div>
        } else {
            return <div className={className}
                id={"Cell_" + this.props.cell.id}
                onClick={this.setFocus}
                onKeyDown={this.onKeyDown}
                tabIndex="0" data-cell={this.props.cell.id}>
                <span className="row">
                    <div className="Cell-cellName col-sm-2">{this.state.name}</div>

                    <div className="col-sm-9">
                        {cellResults}
                    </div>

                    <div className="col-sm-1 text-right">
                        <span className="">&#x2026;</span>
                    </div>
                </span>
            </div>
        }

    }

    
}

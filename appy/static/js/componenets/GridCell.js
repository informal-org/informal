import React from "react";
import ReactDOM from "react-dom";
import AbstractBaseCell from "./AbstractBaseCell.js"
import { cellGet, formatCellOutput } from "../utils"

import Editor from 'react-simple-code-editor';
import CellParam from "./CellParam.js"
import KVTable from "./KVTable"
import { highlight, languages } from 'prismjs/components/prism-core';
import 'prismjs/components/prism-clike';
import 'prismjs/components/prism-javascript';

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
        console.log("Adding row clicked")

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
        let className = "Cell";

        if(this.props.isFocused){
            className += " Cell--focused";
        }
        let cellResults = null;
        let error = cellGet(this.props.cell, "error")
        if(error) {
            className += " Cell--error";
            cellResults = <div className="Cell-cellError">{error}</div>
        } else {
            let valtype = typeof this.props.cell.value;
            if(this.props.cell.value != null && valtype === "object") {
                console.log("Value: " + this.props.cell.value + " is object")
                cellResults = <KVTable value={this.props.cell.value}></KVTable>
            } else {
                let formattedOutput = this.formatOutput();
                if(formattedOutput) {
                    cellResults = <div className="Cell-cellValue">{formattedOutput}</div>
                } else {
                    cellResults = <div className="Cell-cellValue"> &nbsp; </div>
                }                
            }
        }

        let cellBody = null;
        if(this.props.isFocused){
            cellBody = <form onSubmit={this.saveCell} className="Cell-edit container-fluid">


            <i className="fas fa-expand float-right text-gray-700 maximize"></i>

            <div className="row">
                <div className="col-sm-2 inline-block Cell-nameHeader">
                    <label htmlFor="variable_name">Name: </label>
                    <input id="variable_name" className="inline-block Cell-cellName Cell-cellName--edit" placeholder="Name" type="text" onChange={this.changeName} value={this.state.name}></input> 
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
                                highlight={code => highlight(code, languages.js)}
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
        } else {
            cellBody = <span className="row">

            <div className="Cell-cellName col-sm-2">{this.state.name}</div>

            <div className="col-sm-9">
                {cellResults}
            </div>
            
            <div className="col-sm-1 text-right">
            <span className="">
                {/* &#xFF0B; */}
                &#x2026;

            </span>
            </div>



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

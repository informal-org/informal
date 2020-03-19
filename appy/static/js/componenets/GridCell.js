import React from "react";
import ReactDOM from "react-dom";
import AbstractBaseCell from "./AbstractBaseCell.js"
import { cellGet, formatCellOutput } from "../utils.js"

import Editor from 'react-simple-code-editor';
import { highlight, languages } from 'prismjs/components/prism-core';
import 'prismjs/components/prism-clike';
import 'prismjs/components/prism-javascript';

import { addParam } from "../store.js"

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
        console.log("Click handler");
        window.store.dispatch(addParam({
            id: this.props.cell.id
        }))
    }

    renderParams() {
        var params = [];
        for(var i = 0; i < 3; i++) {
            var elem = <input className="block Cell-paramName" key={"param" + i}></input>
            params.push(elem)
        }

        return <div className="Cell-inputs col-sm-2">
            <label>Parameters: </label>
            {params}
            <div className="btn btn-placeholder" onClick={this.addParam}>+ Add Input</div>
        </div>
    }

    render() {
        let className = "Cell shadow-sm";

        if(this.props.isFocused){
            className += " Cell--focused shadow";
        }
        let cellResults = null;
        let error = cellGet(this.props.cell, "error")
        if(error) {
            className += " Cell--error";
            cellResults = <div className="Cell-cellError">{error}</div>
        } else {
            let formattedOutput = this.formatOutput();
            if(formattedOutput) {
                cellResults = <div className="Cell-cellValue">{formattedOutput}</div>
            } else {
                cellResults = <div className="Cell-cellValue"> &nbsp; </div>
            }
        }

        let cellBody = null;
        if(this.props.isFocused){
            cellBody = <form onSubmit={this.saveCell} className="Cell-edit container-fluid">
            <i className="fas fa-expand float-right text-gray-700 maximize"></i>

            <div className="row Cell-nameHeader">
                <div className="col-sm-6 inline-block">
                    <label className="inline-block" htmlFor="variable_name">Name: </label>
                    <input id="variable_name" className="inline-block Cell-cellName Cell-cellName--edit" placeholder="Name" type="text" onChange={this.changeName} value={this.state.name}></input> 
                </div>
                
            </div>

            <div className="row">
                {this.renderParams()}
                
                <div className="Cell-outputs col-sm-10">
                    {/* <input className="Cell-cellValue bg-blue-100 block Cell-cellValue--edit" placeholder="Value" type="text" onChange={this.changeInput} value={this.state.input}></input> */}

                    <label>Value: </label>
                    <ul className="list-group col-sm-10">
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
                        <li className="list-group-item btn btn-placeholder w-full">+ Add row </li>
                    </ul>

                </div>

            </div>

            <input type="submit" className="hidden"/>
          </form>
        } else {
            cellBody = <span className="row">

            <div className="Cell-cellName col-sm-1">{this.state.name}</div>
            <div className="col-sm-11">
                {cellResults}
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

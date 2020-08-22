import React from "react";
import ReactDOM from "react-dom";
import AbstractBaseCell from "./AbstractBaseCell.js"
import { cellGet } from "../utils"
import { formatCellOutput } from "appassembly"

import Editor from 'react-simple-code-editor';
import CellParam from "./CellParam.js"
import CellValue from "./CellValue"
import { highlight, languages } from 'prismjs/components/prism-core';
import './prism-aa';

import { addParam, addRow } from "../store.js"

export default class GridCell extends AbstractBaseCell {
    constructor(props){
        super(props)
        this.state = {
            input: cellGet(props.cell, "expr"),
            name: cellGet(props.cell, "name"),
            docs: cellGet(props.cell, "docs")
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

    addRow = (event) => {
        window.store.dispatch(addRow({
            id: this.props.cell.id
        }))
        this.props.reEvaluate();
        // We use a div button rather than <button>, which requires preventDefault instead.
        event.stopPropagation();
        return false;
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

    renderBody() {
        if(this.props.cell.body.length > 0) {
            var body = [];
            this.props.cell.body.forEach((childId) => {
                let child = this.props.byId[childId];
                var elem = <span key={"Cellbody_" + childId}>
                <GridCell
                cell={child}
                isFocused={false}
                byId={this.props.byId}
                isOpen={false}
                isError={false}
                key={child.id}
                setModified={this.props.setModified}
                setFocus={this.props.setFocus}
                setOpen={this.props.setOpen}
                moveFocus={this.props.moveFocus}
                setInput={this.props.setInput}
                setName={this.props.setName}
                reEvaluate={this.props.reEvaluate}
                />

                </span>
                body.push(elem)
            })

            return <div className="Cell-body">
                {body}
            </div>
        } else {
            return <span></span>
        }
    }

    renderValueEditor() {
        if(this.props.cell.body.length == 0) {
            return <div className="Cell-outputs col-sm-6">

                <label>Value: </label>

                <span className="Cell-action">&#x2026;</span>

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
                </ul>
            </div>
        }
    }

    renderDocsEditor() {
        return <div className="col-sm-4 Cell-cellDocs">
            <label>Description: </label>
            
            <textarea id="variable_name" 
                    className="inline-block Cell-cellDocs--edit" 
                    placeholder="Docs" 
                    type="textarea" 
                    onChange={this.changeDocs} 
                    autoComplete="off"
                    value={this.state.docs}></textarea> 

        </div>
    }

    renderDocs() {
        if(this.state.docs) {
            return <p className="docs">
            {this.state.docs}
            </p>
        } else {
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
                
            }, 100);

            

            return <div className={className}
                id={"Cell_" + cell_id}
                // onClick={this.setFocus}
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

                {this.renderValueEditor()}


                { this.renderDocsEditor() }

            </div>

            <div className="row Cell-body">
                <div className="col-sm-12">
                {this.renderBody()}           
                </div>
            </div>

            

            <div className="row Cell-footer">
                <div className="col-sm-8">
                </div>

                <div className="col-sm-4">
                    <div className="run-link btn btn-outline inline-block" onClick={this.addRow} type="text">
                    &#x2B;  &#160; New cell
                    </div>
                    <button className="run-link btn btn-primary" type="submit">
                        {/* &#8250; Run */}
                        &#x25b6;  &#160; Run
                    </button>
                </div>
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
                    <div className="Cell-cellName col-sm-2">

                        <a className="name inline-block" href="/cell/">
                            {this.state.name}
                        </a>

                        {/* <div className="signature">
                            <dl className="paramSig">
                                    <dt className="name">field</dt> 
                                    <dd className="type">JsonField</dd>

                                    <dt className="name">field_config</dt> 
                                    <dd className="type"> &nbsp;</dd>

                                    <dt className="name">serializer</dt> 
                                    <dd className="type">JsonSerializer</dd>

                                    <dt className="name">tabs</dt> 
                                    <dd className="type">Integer</dd>
                            </dl>
                        </div> */}

                        {/* <span className="returnSig inline-block">
                            Integer
                        </span> */}
                        
                    </div>
                    

                    <div className="col-sm-6 Cell-cellResults">
                        {cellResults}
                    </div>

                    <div className="col-sm-4 text-right">
                        {/* <p className="docs">Code comments would go here in a long descriptive line. <br></br> May contain multiple lines of text.
                        Even some <b>content</b> or <i>italics</i> or images or whatever.</p> */}

                        { this.renderDocs() }

                        {/* <span className="">&#x2026;</span> */}
                    </div>
                </span>
            </div>
        }

    }

    
}

// 2 6 4

// 2 

// 7 3 2
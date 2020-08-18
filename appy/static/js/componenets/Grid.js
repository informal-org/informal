import React from "react";
import GridCell from "./GridCell.js"
import GridList from "./GridList.js"
import EditableLabel from "./EditableLabel.js"
import { addCell, patchView } from "../store.js"
import { KEY_DOWN, KEY_UP, KEY_ENTER, KEY_ESC } from "../constants"
import { $CombinedState } from "redux";


export default class Grid extends React.Component {
    constructor(props) {
        super(props);
    }
    addCellClick = () => {
        console.log("Add cell click")
        window.store.dispatch(addCell())
    }
    isFocused = (cell) => {
        return this.props.focus === cell.id;
    }
    setMethodGet = (event) => {
        console.log(event);
    }
    setMethodPost = (event) => {
        console.log(event);
    }
    setViewName = (newName) => {
        console.log("set view name called")
        window.store.dispatch(patchView({
            "name": newName
        }));
    }
    setViewPattern = (newPattern) => {
        window.store.dispatch(patchView({
            "pattern": newPattern
        }));
    }
    getPreviewUrl = () => {
        if(window._aa_app && window._aa_view) {
            var protocol = window._aa_app.domain === "localhost:9080" ? "http://" : "https://";
            return protocol + window._aa_app.domain + window._aa_view.pattern
        }
        return ""
    }
    onKeyDown = (event) => {
        // Shhh! Don't interrupt typing.
        if(document.activeElement.tagName == "TEXTAREA" || document.activeElement.tagName == "INPUT") {
            return false;
        }

        if (event.keyCode == KEY_UP) {   // 
            event.stopPropagation();
            this.props.moveFocus(-1);
        }
        else if (event.keyCode == KEY_DOWN) {
            event.stopPropagation();
            this.props.moveFocus(1);
        } else if (event.keyCode == KEY_ESC) {
            // ESC with cell selected. Clear focus.
            event.stopPropagation();
            this.props.setFocus(null);
        } else if(event.keyCode == KEY_ENTER) {
            this.props.setOpen(true);
            event.stopPropagation();
        }

    }
    render() {
        const cells = this.props.cells.map((cell) => {
            if(cell.type === "cell"){
                return <GridCell 
                cell={cell}
                isFocused={this.isFocused(cell)}
                byId={this.props.byId}
                isOpen={this.props.open}
                isError={false}
                key={cell.id}
                setModified={this.props.setModified}
                setFocus={this.props.setFocus}
                setOpen={this.props.setOpen}
                moveFocus={this.props.moveFocus}
                setInput={this.props.setInput}
                setName={this.props.setName}
                reEvaluate={this.props.reEvaluate}
                />
            }else if (cell.type === "list") {
                let values = [];
                cell.values.forEach((id) => {
                    values.push(this.props.byId[id]);
                })

                return <GridList 
                cell={cell}
                isFocused={this.isFocused(cell)}
                focus={this.props.focus}
                isError={false}
                key={cell.id}
                setModified={this.props.setModified}
                setFocus={this.props.setFocus}
                setOpen={this.props.setOpen}
                moveFocus={this.props.moveFocus}
                setInput={this.props.setInput}
                setName={this.props.setName}
                reEvaluate={this.props.reEvaluate}
                values = {values}
                />
            }


            // Unknown types are not rendered
            return undefined;
        }).filter((r) => r !== undefined) // Filter out un-rendered cells
        
        return <div>
                <header className="container-fluid editor-header">

                    <div className="row">
                        <div className="col-sm-10 header-title">
                            <EditableLabel 
                                key={this.props.view_name}      // Ensure component is re-rendered when name is fetched
                                value={this.props.view_name}
                                onSave={this.setViewName}>
                            </EditableLabel>
                        </div>

                        <div className="col-sm-2">
                    {/* <a href={ this.getPreviewUrl() } target="_blank">
                        <button className="btn btn-primary">Preview</button>
                    </a> */}
                    </div>

                    </div>

                    <div className="row">

                        <div className="col-sm-12">
                            <p className="docs">Lewis Carroll, author of Alice in Wonderland, was fond of asking children mathematical puzzles. Here's a famous one: Can you draw the following design on a sheet of paper without lifting the pencil from the paper (no intersections allowed)</p>
                        </div>

                        <div className="col-sm-4">
                            {/* <label className="header-label">Route: </label>

                            <EditableLabel 
        key={this.props.view_pattern}      // Ensure component is re-rendered when name is fetched
        value={this.props.view_pattern}
        onSave={this.setViewPattern}
      ></EditableLabel> */}


              {/*
         // Routing methods disabled for MVP currently
         <Descriptions.Item label="Methods">
            <input type="checkbox" checked={this.props.view_m_get} onChange={this.setMethodGet}></input> GET &nbsp;
            <input type="checkbox" checked={this.props.view_m_post} onChange={this.setMethodPost}></input> POST
        </Descriptions.Item>
       */}

                        </div>

                    </div>

                </header>


        
            <div className="Grid" onKeyDown={this.onKeyDown}>
                {cells}

                <button className="btn btn-full btn-outline btn-square fg-primary" onClick={this.addCellClick}>
                    &#x2B;  &#160; New cell
                </button>
            </div>

        </div>
    }
}

import React from "react";
import GridCell from "./GridCell.js"
import GridList from "./GridList.js"
import ActionBar from "./ActionBar.js"
import { addCell } from "../store.js"

import { PageHeader, Button, Descriptions } from 'antd';

export default class Grid extends React.Component {
    constructor(props) {
        super(props);
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
    addCellClick = () => {
        console.log("Doing add cell click")
        console.log(addCell);
        console.log(window.store);
        window.store.dispatch(addCell())
    }
    isFocused = (cell) => {
        return this.props.focus === cell.id;
    }
    render() {
        console.log(this.props.view);
        const cells = this.props.cells.map((cell) => {

            if(cell.type === "cell"){
                return <GridCell 
                cell={cell}
                isFocused={this.isFocused(cell)}
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
                moveFocus={this.props.moveFocus}
                setInput={this.props.setInput}
                setName={this.props.setName}
                reEvaluate={this.props.reEvaluate}
                recomputeCell = {this.recomputeCell}
                values = {values}
                />
            }


            // Unknown types are not rendered
            return undefined;
        }).filter((r) => r !== undefined) // Filter out un-rendered cells
        
        return <div>

<PageHeader
      ghost={false}
      onBack={() => window.history.back()}
      title={this.props.view}
      subTitle="New account creation page."
      extra={[
        <Button key="2">Preview</Button>,
        <Button key="1" type="primary">
          Publish
        </Button>,
      ]}
    >
      <Descriptions size="small" column={3}>
        <Descriptions.Item label="Route">/accounts/signup</Descriptions.Item>
        <Descriptions.Item label="Methods">GET, POST</Descriptions.Item>
        <Descriptions.Item label="Permissions">None</Descriptions.Item>
      </Descriptions>
    </PageHeader>            
        
            <div className="Grid">
                {cells}

                <button className="btn btn-primary" onClick={this.addCellClick}> + </button>
            </div>

        </div>
    }
}

import React from "React";
import ReactDOM from "react-dom";

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

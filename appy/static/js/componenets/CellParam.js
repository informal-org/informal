import React from "react";
import { setParam } from "../store.js"

export default class CellParam extends React.Component {
    constructor(props) {
        super(props);
    }
    setParam = (event) => {
        console.log("Param change handler");
        window.store.dispatch(setParam({
            id: this.props.cell.id,
            param_index: this.props.param_index,
            param_value: event.target.value
        }));
    }
    getParam = () => {
        return this.props.cell.params[this.props.param_index];
    }
    render() {
        return <input value={this.getParam()} onChange={this.setParam}
         className="block Cell-paramName" placeholder="input_name"></input>
    }
}


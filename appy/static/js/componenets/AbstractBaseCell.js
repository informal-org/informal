import React from "react";
import { formatCellOutput } from "../utils.js"

// Abstract base cell that all other cell types inherit from
// Contains common functionality.
export default class AbstractBaseCell extends React.Component {
    constructor(props){
        super(props)
    }

    setFocus = (event) => {
        this.props.reEvaluate();    // Potentially re-evaluate the result of previous cell modification.
        this.props.setFocus(this.props.cell.id);
    }

    clearFocus = () => {
        this.props.setFocus(null);
    }

    onKeyDown = (event) => {
        // Only process events that happen directly on the outer div, not in inner inputs, etc.
        let isCellTarget = event.target.dataset["cell"] === this.props.cell.id;
        if(isCellTarget){
            // Deferred - up = 38, down=40. Requires more complex calculation to get grid pos.
            if (event.keyCode == 37) {
                // Left arrow
                this.props.moveFocus(-1);
            }
            else if (event.keyCode == 39) {
                // Right arrow
                this.props.moveFocus(1);
            } else if (event.keyCode == 27) {
                // ESC with cell selected. Clear focus.
                this.clearFocus();
            }
        } else if (event.keyCode == 27) {
            // ESC
            // De-select input and set focus back on cells
            event.target.blur();
            event.target.closest(".Cell").focus();
        }
    }

    changeInput = (event) => {
        let input = event.target.value;
        this.props.setInput({id: this.props.cell.id, input: input})
        this.setState({input: input});
        this.props.setModified();
    }

    changeName = (event) => {
        let name = event.target.value;
        this.props.setName({id: this.props.cell.id, name: name})
        this.setState({name: name});
        this.props.setModified();
    }

    formatOutput = () => {
        return formatCellOutput(this.props.cell);
    }

}

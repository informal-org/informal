import React from "react";
import { formatCellOutput } from "../utils"


const KEY_UP = 38;
const KEY_DOWN = 40;
const KEY_LEFT = 37;
const KEY_RIGHT = 38;
const KEY_ESC = 27;

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
        console.log(event)
        // Only process events that happen directly on the outer div, not in inner inputs, etc.
        let isCellTarget = event.target.dataset["cell"] === this.props.cell.id;
        if(isCellTarget){
            console.log("is target cell: " + event.keyCode)
            if (event.keyCode == KEY_UP) {   // 
                this.props.moveFocus(-1);
                event.stopPropagation();
            }
            else if (event.keyCode == KEY_DOWN) {
                this.props.moveFocus(1);
                event.stopPropagation();
            } else if (event.keyCode == KEY_ESC) {
                // ESC with cell selected. Clear focus.
                this.clearFocus();
                event.stopPropagation();
            }
        } else if (event.keyCode == KEY_ESC) {
            // De-select input and set focus back on cells
            event.target.blur();
            event.target.closest(".Cell").focus();
        }
    }

    changeInput = (event) => {
        // let input = event.target.value;
        // Event.target.value - when using input field. event when using the editor.
        let input = event;
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

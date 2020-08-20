import React from "react";
import { formatCellOutput } from "appassembly"
import { KEY_DOWN, KEY_UP, KEY_ENTER, KEY_ESC } from "../constants"


// Abstract base cell that all other cell types inherit from
// Contains common functionality.
export default class AbstractBaseCell extends React.Component {
    constructor(props){
        super(props)
    }

    setFocus = (event) => {
        this.props.reEvaluate();    // Potentially re-evaluate the result of previous cell modification.
        this.props.setOpen(true);
        this.props.setFocus(this.props.cell.id);
    }

    clearFocus = () => {
        this.props.setFocus(null);
    }

    onKeyDown = (event) => {
        // Only process events that happen directly on the outer div, not in inner inputs, etc.
        let isCellBase = event.target.dataset["cell"] === this.props.cell.id;
        let isCellInput = event.target.tagName === "INPUT" || event.target.tagName == "TEXTAREA";
        if(isCellBase){
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
        } else if(isCellInput && event.keyCode === KEY_ENTER && event.shiftKey) {
            // Shift-enter = save and evaluate. 
            // We chose shift-enter rather than enter so new line works consistently across desktop
            // and mobile (iOS doesn't support soft-enter).
            event.target.blur();
            event.target.closest(".Cell").focus();
            event.stopPropagation();
            this.props.reEvaluate();
            this.props.setOpen(false)
        }
        else if (!isCellInput && event.keyCode == KEY_ENTER) {
            event.target.blur();
            event.target.closest(".Cell").focus();
            event.stopPropagation();
            this.props.setOpen(true);
        }
        else if (event.keyCode == KEY_ESC) {
            // De-select input and set focus back on cells
            event.target.blur();
            event.target.closest(".Cell").focus();
            event.stopPropagation();
            this.props.setOpen(false);
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

    changeDocs = (event) => {
        let docs = event.target.value;
        this.props.setDocs({id: this.props.cell.id, docs: docs})
        this.setState({docs: docs});
    }

    formatOutput = () => {
        return formatCellOutput(this.props.cell);
    }

}

import React from "react";

export default class EditableLabel extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            isEdit: false,
            editValue: this.props.value
        }
    }
    setEdit = () => {
        this.setState({
            isEdit: true
        })
    }
    saveInput = (event) => {
        this.props.onSave(this.state.editValue);
        this.setState({
            isEdit: false
        })

        event.preventDefault();
        return true;
    }
    editInput = (event) => {
        this.setState({
            editValue: event.target.value
        })
    }
    render() {
        if(this.state.isEdit) {
            return <form className="form-group container editable-label" onSubmit={this.saveInput}>
                <div className="row">
                    <input type="text" value={this.state.editValue} onChange={this.editInput} className="form-control inline-block col-md-9"></input>
                    <input type="submit" value="Save" className="btn btn-secondary col-md-3"/>
                </div>
            </form>
        } else {
            var editStyle = {
                fontSize: "0.65rem",
                paddingLeft: "0.65rem"
            }

            return <div>
                <label>{this.props.value}</label>
                <small style={editStyle}>
                    <a onClick={this.setEdit}>Edit</a>
                </small>
            </div>
        }
    }
}
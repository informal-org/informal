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
            return <form className="form-group editable-label inline-block" onSubmit={this.saveInput}>
                    <div className="input-group mb-3">
                    <input type="text" value={this.state.editValue} onChange={this.editInput} className="form-control"></input>
                    <div className="input-group-append">
                        <input type="submit" value="Save" className="btn btn-secondary"/>
                    </div>
                    </div>
                    

            </form>
        } else {
            var editStyle = {
                fontSize: "0.65rem",
                paddingLeft: "0.65rem"
            }

            var labelStyle = {
                cursor: "text"
            }

            return <span className="inline-block">
                <label style={labelStyle} onClick={this.setEdit}>{this.props.value}</label> &nbsp;
                <small style={editStyle}>
                    {/* <a onClick={this.setEdit}>Edit</a> */}
                </small>
            </span>
        }
    }
}
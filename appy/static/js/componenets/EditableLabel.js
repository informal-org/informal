import React from "react";

export default class EditableLabel extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            isEdit: false
        }
    }
    setEdit = () => {
        this.setState({
            isEdit: true
        })
    }
    saveInput = () => {
        this.props.onSave();
        this.setState({
            isEdit: false
        })
    }
    render() {
        if(this.state.isEdit) {
            return <form>
                <input type="text" value={this.props.input}></input>
                <input type="submit" onSubmit={this.saveInput}/>
            </form>
        } else {
            var editStyle = {
                fontSize: "0.75rem",
                paddingLeft: "0.75rem"
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
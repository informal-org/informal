import React from "react";
import ReactDOM from "react-dom";

export default class ActionBar extends React.Component {
    render() {
        return <div className="ActionBar">
            <div className="inline-block">
                <div className="ActionBar-action" onClick={this.props.decWidth} >
                    -
                </div>
                <div className="px-3 py-2 inline-block">
                Width
                </div>
                <div className="ActionBar-action" onClick={this.props.incWidth} >
                    +
                </div>
            </div>

            <div className="inline-block">
                <div className="ActionBar-action" onClick={this.props.decHeight} >
                    -
                </div>
                <div className="px-3 py-2 inline-block">
                Height
                </div>
                <div className="ActionBar-action" onClick={this.props.incHeight} >
                    +
                </div>
            </div>
        </div>
    }
}

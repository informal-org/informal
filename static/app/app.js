import React from 'react';
import ReactDOM from 'react-dom';
import {Editor, EditorState, RichUtils} from 'draft-js';
import {MegadraftEditor, editorStateFromRaw} from "megadraft";
import { convertToRaw } from "draft-js";




function postData(url = ``, data = {}) {
    // Default options are marked with *
    var csrf_token = document.querySelector("[name='csrfmiddlewaretoken']").getAttribute("value");
    data['csrfmiddlewaretoken'] = csrf_token;

    const searchParams = new URLSearchParams();
    for (const prop in data) {
      searchParams.set(prop, data[prop]);
    }



    return fetch(url, {
        method: "POST",
        headers: {
            // "Content-Type": "application/json; charset=utf-8",
            "Content-Type": "application/x-www-form-urlencoded",
            "X-CSRFToken": csrf_token
        },
        credentials: 'same-origin', // Include cookies
        body: searchParams, // body data type must match "Content-Type" header
    })
    .then(response => {
        console.log("Got response ")
        console.log(response);
        return "OK"
    }); // parses response to JSON
}


export function editorStateToJSON(editorState) {
    // Modified from megadraft but removing spaces.
  // https://github.com/globocom/megadraft/blob/f8051429712580f230b8c2f98326aa2171d661b3/src/utils.js#L17
  if (editorState) {
    const content = editorState.getCurrentContent();
    return JSON.stringify(convertToRaw(content), null, 0);
  }
}




class ArevelApp extends React.Component {
    constructor(props) {
        super(props);
        // this.state = {editorState: editorStateFromRaw(null)};
        const content = window._initialData.doc.contents;
        const editorState = editorStateFromRaw(content);
        this.state = {editorState, isSaved: true};
    }

    onChange = (editorState) => {
        this.setState({editorState, isSaved: false});
    };

    render() {
        let saveBtn;
        if(this.state.isSaved){
            saveBtn = <a className="btn btn-outline-primary btn-rect pull-right" href="#" onClick={this.onSaveClick}>
                Saved
            </a>
        } else {
            saveBtn = <a className="btn btn-primary btn-rect pull-right" href="#" onClick={this.onSaveClick}>
                Save
            </a>
        }

        return (
            <div>
                <nav className="navbar navbar-expand-lg navbar-light bg-light ToolbarMenu">

                    <ul className="navbar-nav mr-auto">
                        {/*<li className="nav-item active">*/}
                            {/*<a className="nav-link" href="#">Home <span className="sr-only">(current)</span></a>*/}
                        {/*</li>*/}
                        {/*<li className="nav-item">*/}
                            {/*<a className="nav-link" href="#">Link</a>*/}
                        {/*</li>*/}
                        {/*<li className="nav-item dropdown">*/}
                            {/*<a className="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button"*/}
                               {/*data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">*/}
                                {/*Dropdown*/}
                            {/*</a>*/}
                            {/*<div className="dropdown-menu" aria-labelledby="navbarDropdown">*/}
                                {/*<a className="dropdown-item" href="#">Action</a>*/}
                                {/*<a className="dropdown-item" href="#">Another action</a>*/}
                                {/*<div className="dropdown-divider"></div>*/}
                                {/*<a className="dropdown-item" href="#">Something else here</a>*/}
                            {/*</div>*/}
                        {/*</li>*/}
                    </ul>

                    <form className="form-inline">
                        {saveBtn}
                    </form>

                </nav>


                <MegadraftEditor
                    editorState={this.state.editorState}
                    onChange={this.onChange}
                    placeholder={"Write here..."}
                />

            </div>
        )
    }

    onSaveClick = () => {
        const {editorState} = this.state;
        const content = editorStateToJSON(editorState);

        var saveUrl = "/docs/" + window._initialData.doc.uuid;
        var saveData = {
            'contents': content
        };
        console.log("Saving to " + saveUrl);

        // Eventually - send just the diff
        postData(saveUrl, saveData);

        this.setState({isSaved: true});
        console.log(content);
    };
}



let domContainer = document.querySelector('#root');
ReactDOM.render(<ArevelApp />, domContainer);

console.log("Hello world")
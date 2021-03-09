import React from 'react';
import ReactDOM from 'react-dom';
import {
    Editor,
    EditorState,
    RichUtils,
    convertToRaw,
    CompositeDecorator
} from 'draft-js';
import {MegadraftEditor, editorStateFromRaw, createTypeStrategy} from "megadraft";

import Link from "megadraft/lib/components/Link";
import LinkInput from "megadraft/lib/entity_inputs/LinkInput";


import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import actions from "megadraft/lib/actions/default"
import icons from "megadraft/lib/icons"

import { faEquals } from '@fortawesome/free-solid-svg-icons'




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
        let content = window._initialData.doc.contents;
        // Cannot do == {}
        if(!content || Object.keys(content).length == 0){
            content = null;
        }

        const decorator = new CompositeDecorator([
            {
              strategy: createTypeStrategy("LINK"),
              component: Link
            },
            {
              strategy: createTypeStrategy("REFERENCE"),
              component: ArReference,
            },
        ]);


        const name = window._initialData.doc.name;
        const editorState = editorStateFromRaw(content, decorator);
        this.state = {editorState, name, isSaved: true};
    }

    onChange = (editorState) => {
        this.setState({editorState, isSaved: false});
    };

    rename = (event) => {
        this.setState({name: event.target.value, isSaved: false});
    };

    getSidebar() {
        // Disable sidebar for now...
        return <span></span>
    }

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

        const customActions = actions.concat([
            {type: "separator"},
            {type: "entity", label: "R", style: "REFERENCE", icon: ReferenceIcon, entity: "REFERENCE"}
        ]);

        const entityInputs = {
          LINK: LinkInput,
          REFERENCE: ArRefInput
        };


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
                        <li className="nav-item">
                             <input placeholder="Untitled..." className="form-control Doc-nameInput" type="text" value={this.state.name} onChange={this.rename} />
                        </li>
                    </ul>

                    <form className="form-inline">
                        {saveBtn}
                    </form>

                </nav>


                <MegadraftEditor
                    editorState={this.state.editorState}
                    onChange={this.onChange}
                    placeholder={"Write here..."}
                    actions={customActions}
                    sidebarRendererFn={this.getSidebar}
                    entityInputs={entityInputs}
                />

            </div>
        )
    }

    onSaveClick = () => {
        const {editorState} = this.state;
        const content = editorStateToJSON(editorState);

        var saveUrl = "/docs/" + window._initialData.doc.uuid;
        var saveData = {
            'name': this.state.name,
            'contents': content
        };
        console.log("Saving to " + saveUrl);

        // Eventually - send just the diff
        postData(saveUrl, saveData);

        this.setState({isSaved: true});
        console.log(content);
    };
}


// todo: high level abstraction for this.
// function findRefEntities(contentBlock, callback, contentState) {
//     console.log("Find ref entities called");
//     contentBlock.findEntityRanges(
//       (character) => {
//         const entityKey = character.getEntity();
//         return (
//           entityKey !== null &&
//           contentState.getEntity(entityKey).getType() === 'REFERENCE'
//         );
//       },
//       callback
//     );
// }



class ArReference extends React.Component {
    render() {
        const contentState = this.props.contentState;
        const { code } = contentState.getEntity(this.props.entityKey).getData();
        return <a className="DocContent-reference">
            <b>{this.props.children} {code}</b>
        </a>
    }
}

class ArRefInput extends React.Component {
    constructor(props) {
        super(props);

        console.log("Reference input constructor")
        this.state = {
            code: (props && props.code) || ""
        }

        // this.onInputChange = this.onInputChange;
        // this.onInputKeyDown = this.onInputKeyDown;
        this.onInputChange = this.onInputChange.bind(this);
        this.onInputKeyDown = this.onInputKeyDown.bind(this);
    }


    onInputChange = (event) => {
        const code = event.target.value;
        this.setState({code})
        // this.props.setEntity({code});
    };

    onInputKeyDown(event) {
        if (event.key == "Enter") {
          event.preventDefault();
          this.props.setEntity({code});
        } else if (event.key == "Escape") {
          event.preventDefault();
          this.props.cancelEntity();
        }
    }

    componentDidMount() {
        this.textInput.focus();
    }

    render() {
        console.log("Reference input render")
        const { t } = this.props;
        return (
          <div style={{ whiteSpace: "nowrap" }}>
            <input
              ref={el => {
                this.textInput = el;
              }}
              type="text"
              className="toolbar__input"
              onChange={this.onInputChange}
              value={this.state.code}
              onKeyDown={this.onInputKeyDown}
              placeholder={"Type the code and press enter"}
            />
            <span className="toolbar__item" style={{ verticalAlign: "bottom" }}>
              <button
                onClick={this.props.removeEntity}
                type="button"
                className="toolbar__button toolbar__input-button"
              >
                {this.props.entity ? <FontAwesomeIcon icon={faEquals} /> : <icons.CloseIcon />}
              </button>
            </span>
          </div>
        );

    }
}

class ReferenceIcon extends React.Component {
  render() {
    return (
        <FontAwesomeIcon icon={faEquals} />
    );
  }
}





let domContainer = document.querySelector('#root');
ReactDOM.render(<ArevelApp />, domContainer);

console.log("Hello world")
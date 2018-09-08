import React from 'react';
import ReactDOM from 'react-dom';
import {Editor, EditorState, RichUtils} from 'draft-js';

import {MegadraftEditor, editorStateFromRaw, editorStateToJSON} from "megadraft";



class AvEditor extends React.Component {
    constructor(props) {
        super(props);
        this.state = {editorState: EditorState.createEmpty()};
        this.onChange = (editorState) => this.setState({editorState});
        this.handleKeyCommand = this.handleKeyCommand.bind(this);
    }

    handleKeyCommand(command, editorState) {
        // Apply bold, italics, etc.
        const newState = RichUtils.handleKeyCommand(editorState, command);
        if (newState) {
            this.onChange(newState);
            return 'handled';
        }
        return 'not-handled';
    }

    render() {
        return (
            <Editor editorState={this.state.editorState}
                    handleKeyCommand={this.handleKeyCommand}
                    onChange={this.onChange} />
        );
    }
}


class ArevelApp extends React.Component {
  constructor(props) {
    super(props);
    // this.state = {editorState: editorStateFromRaw(null)};

    const content = {
      "entityMap": {},
      "blocks": [
        {
          "key": "ag6qs",
          "text": "Hello world",
          "type": "unstyled",
          "depth": 0,
          "inlineStyleRanges": [],
          "entityRanges": [],
          "data": {}
        }
      ]
    };

    const editorState = editorStateFromRaw(content);
    this.state = {editorState};


  }

  onChange = (editorState) => {
    this.setState({editorState});
  };

  onSaveClick = () => {
    const {editorState} = this.state;
    const content = editorStateToJSON(editorState);
    // Your function to save the content
    // save_my_content(content);
    console.log(content);
  };


  render() {
    return (
        <div>
      <MegadraftEditor
        editorState={this.state.editorState}
        onChange={this.onChange}/>


            <button onClick={this.onSaveClick}>
                Save
            </button>

        </div>
    )
  }
}



let domContainer = document.querySelector('#root');
ReactDOM.render(<ArevelApp />, domContainer);

console.log("Hello world")
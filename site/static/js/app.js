// Import CSS so webpack loads it. MiniCssExtractPlugin will split it.
import '../css/app.css';
import { connect } from 'react-redux'
import { Provider } from 'react-redux'
import { mapStateToProps, mapDispatchToProps } from './store.js'
import Grid from './componenets/Grid.js'
import React from "react";
import ReactDOM from "react-dom";



const ConnectedGrid = connect(
    mapStateToProps,
    mapDispatchToProps
  )(Grid)
 
ReactDOM.render(
    <Provider store={store}>
        <ConnectedGrid/>
    </Provider>,
    document.getElementById('root')
);



import { Tree, Icon } from 'antd';
import "antd/dist/antd.css";

const { TreeNode } = Tree;

class Sidebar extends React.Component {
  onSelect = (selectedKeys, info) => {
    console.log('selected', selectedKeys, info);
  };

  render() {
    return (
      <Tree
        showLine
        switcherIcon={<Icon type="down" />}
        defaultExpandedKeys={['0-0-0']}
        onSelect={this.onSelect}
      >
        <TreeNode title="accounts" key="0-0">
          <TreeNode title="signup" key="0-0-0"></TreeNode>
          <TreeNode title="login" key="0-0-1"></TreeNode>
          <TreeNode title="settings" key="0-0-2">
            <TreeNode title="contact" key="0-0-2-0" />
            <TreeNode title="privacy" key="0-0-2-1" />
          </TreeNode>
        </TreeNode>
      </Tree>
    );
  }
}

ReactDOM.render(<Sidebar />, document.getElementById('aa-sidebar-views'));
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



// import { Menu, Tree, Icon } from 'antd';
// import Menu from 'antd/es/menu';
// import Tree from 'antd/es/tree';
// import Icon from 'antd/es/icon';

import { Menu } from 'antd';
import { Tree } from 'antd';

const { SubMenu } = Menu;
const { TreeNode } = Tree;

class Sidebar extends React.Component {
  rootSubmenuKeys = ['views', 'data'];

  state = {
    views: [],
    openKeys: ['views', 'data'],
  };

  componentWillMount = () => {
    console.log("Component will mount called")

    let parent = this;
    fetch('/api/v1/apps/' + window._aa_appid + '?format=json').then((data) => {
      console.log("got response");
      return data.json();
    }).then((apps) => {
      console.log("apps");
      console.log(apps);

      parent.setState({
        'views': apps[0]['view_set'],
        'openKeys': parent.state.openKeys
      })
      
    })
  }

  // Navbar sub menu open/close
  onOpenChange = openKeys => {
    this.setState({
        openKeys: openKeys
    })
  };

  // Tree menu select
  onSelect = (selectedKeys, info) => {
    console.log('selected', selectedKeys, info);
  };

  renderViews() {
    // TODO: Nest these properly
    let elements = [];
    let id = 0;
    this.state.views.forEach((view) => {
      let key = '0-' + id;
      let elem = <TreeNode title={view.name} key={key}></TreeNode>
      id+=1;
      elements.push(elem);
    })

    return <Tree
      showLine
      switcherIcon={<span>&#x2304;</span>}
      defaultExpandedKeys={['0-0-0']}
      onSelect={this.onSelect}
      style={{ paddingLeft: 24 }}
    >
    {elements}
    </Tree>
  }

  render() {
    return (
      <Menu
        mode="inline"
        openKeys={this.state.openKeys}
        onOpenChange={this.onOpenChange}
        style={{ width: "100%", minWidth: 180, maxWidth: 256, height: "100%" }}
      >
        <SubMenu
          key="views"
          title={
            <span>
              <span>Views</span>
            </span>
          }
        >
          {this.renderViews()}

        </SubMenu>
        <SubMenu
          key="data"
          title={
            <span>
              <span>Data</span>
            </span>
          }
        >
          <Menu.Item key="5">Users</Menu.Item>
          <Menu.Item key="6">Posts</Menu.Item>
          <Menu.Item key="7">Comments</Menu.Item>
        </SubMenu>
      </Menu>
    );
  }
}

// ReactDOM.render(<Sidebar />, mountNode);






// 

// class Sidebar extends React.Component {
//   onSelect = (selectedKeys, info) => {
//     console.log('selected', selectedKeys, info);
//   };

//   render() {
//     return (
//       <Tree
//         showLine
//         switcherIcon={<Icon type="down" />}
//         defaultExpandedKeys={['0-0-0']}
//         onSelect={this.onSelect}
//       >
//         <TreeNode title="accounts" key="0-0">
//           <TreeNode title="signup" key="0-0-0"></TreeNode>
//           <TreeNode title="login" key="0-0-1"></TreeNode>
//           <TreeNode title="settings" key="0-0-2">
//             <TreeNode title="contact" key="0-0-2-0" />
//             <TreeNode title="privacy" key="0-0-2-1" />
//           </TreeNode>
//         </TreeNode>
//       </Tree>
//     );
//   }
// }

ReactDOM.render(<Sidebar />, document.getElementById('aa-sidebar'));
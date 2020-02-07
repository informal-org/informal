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
import { loadView } from './store.js'

const { SubMenu } = Menu;
const { TreeNode } = Tree;

class Sidebar extends React.Component {
  rootSubmenuKeys = ['views', 'data'];

  state = {
    views: [],
//    openKeys: ['views', 'data'],
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
      window._aa_app = apps;
      window._aa_viewid = apps['view_set'][0]['uuid'];

      store.dispatch(loadView());

      parent.setState({
        'views': apps['view_set'],
//        'openKeys': parent.state.openKeys
      })
      
    })
  }

  // // Navbar sub menu open/close
  // onOpenChange = openKeys => {
  //   this.setState({
  //       openKeys: openKeys
  //   })
  // };

  // Tree menu select
  onSelect = (selectedKeys, info) => {
    console.log('selected', selectedKeys, info);
  };

  createViewBtn() {
    return <form method="POST"
          action={"/apps/" + window._aa_appid + "/views/create"}>
            <button className="pull-right ant-btn btn-primary" type="submit">New View</button>
          </form>
  }

  renderViews() {
    // TODO: Nest these properly
    let elements = [];
    let id = 0;
    this.state.views.forEach((view) => {
      let key = '0-' + id;
      let link = <a href={"/apps/" + window._aa_appid + "/views/" + view.uuid} >{view.name}</a>
      let elem = <TreeNode title={link} key={key}></TreeNode>
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
    <TreeNode key="create" title={this.createViewBtn()}></TreeNode>
    </Tree>
  }

  render() {
    // Width 180-256
    return (
      <nav id="aa-sidebar">
        <section>
          <h3 class="aa-sidebar-section">Views</h3>
          <ul class="list-unstyled">
            <li>One</li>
            <li>Two</li>
            <li>Two</li>
          </ul>
        </section>
        <ul class="list-unstyled">
            <li class="active">
                <a href="#homeSubmenu" data-toggle="collapse" aria-expanded="false" class="dropdown-toggle">Home</a>
                <ul class="collapse list-unstyled" id="homeSubmenu">
                    <li>
                        <a href="#">Home 1</a>
                    </li>
                    <li>
                        <a href="#">Home 2</a>
                    </li>
                    <li>
                        <a href="#">Home 3</a>
                    </li>
                </ul>
            </li>
            <li>
                <a href="#">About</a>
            </li>
            <li>
                <a href="#pageSubmenu" data-toggle="collapse" aria-expanded="false" class="dropdown-toggle">Pages</a>
                <ul class="collapse list-unstyled" id="pageSubmenu">
                    <li>
                        <a href="#">Page 1</a>
                    </li>
                    <li>
                        <a href="#">Page 2</a>
                    </li>
                    <li>
                        <a href="#">Page 3</a>
                    </li>
                </ul>
            </li>
            <li>
                <a href="#">Portfolio</a>
            </li>
            <li>
                <a href="#">Contact</a>
            </li>
        </ul>

        
      </nav>

      // <Menu
      //   mode="inline"
      //   openKeys={this.state.openKeys}
      //   onOpenChange={this.onOpenChange}
      //   style={{ width: "100%", minWidth: 180, maxWidth: 256, height: "100%" }}
      // >
      //   <SubMenu
      //     key="views"
      //     title={
      //       <span>
      //         <span>Views</span>
      //       </span>
      //     }
      //   >
      //     {this.renderViews()}

      //   </SubMenu>
      // </Menu>
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

ReactDOM.render(<Sidebar />, document.getElementById('aa-sidebar-wrapper'));
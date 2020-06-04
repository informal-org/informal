import React from "react";
import { loadView } from '../store.js'

export default class Sidebar extends React.Component {
  state = {
    views: [],
  };

  componentDidMount = () => {
    let parent = this;
    fetch('/api/v1/apps/' + window._aa_appid + '?format=json').then((data) => {
      return data.json();
    }).then((apps) => {
      window._aa_app = apps;
      store.dispatch(loadView());

      parent.setState({
        'views': apps['view_set'],
      })
      
    })
  }

  createViewBtn() {
    return <form method="POST"
          action={"/apps/" + window._aa_appid + "/views/create"}>
            <input type='hidden' name='csrfmiddlewaretoken' value={ window._csrf_token } />
            <button className="pull-right btn btn-outline" type="submit">New View</button>
          </form>
  }

  renderViews() {
    // TODO: Nest these properly
    let elements = [];
    let id = 0;
    this.state.views.forEach((view) => {
      let key = '0-' + id;
      let link = <li key={view.shortuuid}><a href={"/apps/" + window._aa_appid + "/views/" + view.shortuuid + "/edit"}>{view.name}</a></li>
      id+=1;
      elements.push(link);
    })

    return <ul className="list-unstyled sidebar-list">
    {elements}
    {this.createViewBtn()}
    </ul>
  }

  render() {
    // Width 180-256
    return (
      <nav id="aa-sidebar">
        <section className="aa-sidebar-section">
          <h3>Views</h3>
          
            {this.renderViews()}

        </section>        
      </nav>

    );
  }
}

import React from "react"

export default class KVTable extends React.PureComponent {
    constructor(props) {
        super(props)
    }

    render() {
        var rows = [];
        Object.entries(this.props.value).forEach((kv) => {
            let [key, value] = kv;
            rows.push(
                <tr key={key}>
                    <td>{ key }</td>
                    <td>&nbsp;:&nbsp;</td>
                    <td>{ value }</td>
                </tr>
            )
        })
        return <table>
            <tbody>
            {rows}
            </tbody>
        </table>
    }

}
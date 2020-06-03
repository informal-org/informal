import React from "react"

export default class KVTable extends React.PureComponent {
    constructor(props) {
        super(props)
    }

    render() {
        var rows = [];
        let obj = this.props.value;
        obj.pseudokeys().forEach((pseudokey) => {
            let key = obj.getKey(pseudokey);
            let value = obj._values[pseudokey];
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
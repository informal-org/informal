import React from "react"

export default class KVTable extends React.PureComponent {
    constructor(props) {
        super(props)
    }

    renderValue(value) {
        let valtype = typeof value;
        let cellResults;
        if(valtype == "function") {
            // Ignore the header
            let formattedOutput = "" + value;
            formattedOutput = formattedOutput.slice(formattedOutput.indexOf("=>") + 2, formattedOutput.length);
            cellResults = <div className="Cell-cellValue">{formattedOutput}</div>
        }
        else if(Array.isArray(value)) {
            cellResults =  <div className="Cell-cellValue">{"" + value}</div>
        }
        else if(value != null && valtype === "object") {
            cellResults = <KVTable value={value}></KVTable>
        } else {
            let formattedOutput = "" + value;
            cellResults = <div className="Cell-cellValue">{formattedOutput}</div>
        }

        return cellResults
    }

    render() {
        var rows = [];
        let obj = this.props.value;
        let i =0;
        console.log(obj)
        if(obj.data) {
            return this.renderValue(obj.data)
        } else if(obj.pseudokeys) {
            obj.pseudokeys().forEach((pseudokey) => {
                let key = obj.getKey(pseudokey);
                let value = obj._values[pseudokey];
    
                rows.push(
                    <tr key={i++}>
                        <td>{ this.renderValue(key) }</td>
                        <td>&nbsp;:&nbsp;</td>
                        <td>{ this.renderValue(value) }</td>
                    </tr>
                )
            })
        } else {
            return this.renderValue(obj);
        }

        return <table>
            <tbody>
            {rows}
            </tbody>
        </table>
    }

}
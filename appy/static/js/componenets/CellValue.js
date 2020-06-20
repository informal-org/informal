import React from "react"
import { highlight, languages } from 'prismjs/components/prism-core';
// import 'prismjs/components/prism-clike';
// import 'prismjs/components/prism-javascript';
// import 'prismjs/components/prism-ruby';
import './prism-aa';


export default class CellValue extends React.PureComponent {
    constructor(props) {
        super(props)
    }

    formatOutput(value) {
        if(value === undefined || value === null){
            return ""
        }
        else if(value === true) {
            return "true"
        } 
        else if(value === false) {
            return "false"
        }
        else if(typeof value == "string") {
            return '"' + value + '"'
        }
        else if(typeof value == "function") {
            let fun_string = "" + value;
            fun_string = fun_string.slice(fun_string.indexOf("=>") + 2);
            return fun_string
        }
        else {
            return "" + value
        }    
    }

    highlightOutput(value) {
        // TODO: if no output
        return {__html: highlight(this.formatOutput(value), languages.aa)}
    }

    renderValue(value) {
        let valtype = typeof value;
        let cellResults;
        if(Array.isArray(value)) {
            cellResults =  <div className="Cell-cellValue">{"" + value }</div>
        }
        else if(value != null && valtype === "object") {
            if(value.__type === "Stream") {
                cellResults =  <div className="Cell-cellValue">{"" + Array.from(value.iter()) }</div>
            } else if(value.__type == "KeySig") {
                cellResults = <div className="Cell-cellValue">{"" + value }</div>
            }
            else {
                cellResults = <div className="Cell-cellValue">{"" + value }</div>
            }
            
        } else {
            // TODO: Verify no XSS
            cellResults = <div className="Cell-cellValue" 
            dangerouslySetInnerHTML={this.highlightOutput(value)}>
            </div>
        }

        return cellResults
    }

    render() {
        var rows = [];
        let obj = this.props.value;
        let i =0;
        console.log(obj)
        if(obj === undefined || obj === null) {
            return <div className="Cell-cellValue"> &nbsp; </div>
        }
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


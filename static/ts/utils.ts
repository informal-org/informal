// src/utils.ts
import { Big } from 'big.js';
import { Value } from './engine/engine';
import * as constants from "./constants";


export function unboxVal(value: any){
    if(value !== undefined && value !== null && value.evaluate !== undefined){
        return value.evaluate();
    }
    return value;
}


Array.prototype.remove = function(item) {
    if(this.indexOf(item) != -1){
        this.splice(this.indexOf(item), 1);
    }
};


// https://stackoverflow.com/questions/5306680
Array.prototype.move = function (old_index, new_index) {
    if (new_index >= this.length) {
        var k = new_index - this.length;
        while ((k--) + 1) {
            this.push(undefined);
        }
    }

    this.splice(new_index, 0, this.splice(old_index, 1)[0]);
    return this; // for testing purposes
};


// TODO: Does this work when used?
String.prototype.plus = function(other) {
    console.log("Adding")
    return this + other;
};


export function generate_random_id(){
    // Source: S/O 105034 - Broofa
    return 'xxxxxxxxxxxxxxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

export function castNumber(value: string) {
    try {
        return Big(value)
    } catch(err){
        // Kinda expected error since we're doing trial-and-failure typing.
        return undefined;
        // Error: [big.js] Invalid number
    }
}

export function cleanBoolStr(value: string) {
    return value.toString().trim().toUpperCase()
}

export function castBoolean(value: string) {
    let cleaned = cleanBoolStr(value);
    if(cleaned === "TRUE") return true;
    else if(cleaned === "FALSE") return false;
    return undefined;
}

export function isBoolean(value: string | boolean){
    return isTrue(value) || isFalse(value);
}


export function isTrue(value: string | boolean) {
    // Checks is true or
    // @ts-ignore: Allow booleans
    return value === true ||  cleanBoolStr(value) === "TRUE";
}

export function isFalse(value: string | boolean){
    // @ts-ignore: Allow booleans
    return value === false ||  cleanBoolStr(value) === "FALSE";
}

export function isString(value: any) {
    return typeof value === (typeof "string") || value instanceof String;
}

export function isFormula(value: string){
    if(isDefinedStr(value)){
        let valStr = value.toString().trim();
        return valStr.length > 0 && valStr[0] == "=";
    }
    return false;
}

export function isBigNum(value: any) {
    // == Big, but the class name gets mangled in minification. So indirect ref.
    return isInstanceOf(value, constants.ZERO.constructor.name)
}

export function isNumber(value: any) {
    return isBigNum(value) || typeof value === (typeof 0);
}

export function isInstanceOf(value: any, class_name: string) {
    if(value !== undefined && value !== null && value.constructor !== undefined){
        return value.constructor.name === class_name
    }
    return false
}

export function isCell(value: any) {
    return isInstanceOf(value, Value.constructor.name)
}

export function castLiteral(value: string){
    if(isDefinedStr(value)){
        let bool = castBoolean(value);
        if(bool !== undefined){
            return bool
        }
        let num = castNumber(value);
        if(num !== undefined){
            return num;
        }
    }
    // Return raw string value
    return value;
}

export function fudge(result: Big) {
    // If the difference in decimal places and the max is less than the precision we care about, fudge it.
    // Fudge the result of a computation for rounding errors
    // i.e (1/3) * 3 = 1 rather than 0.9999999
    // 0.33333333333333333333 = 20 decimals
    let decimal = result.mod(constants.ONE);
    let p = ".00000000000000000001"
    let precision = Big(p);  // 20 decimals

    let max = constants.ONE.minus(precision);
    if(decimal.gt(constants.ZERO)){
        // 0.99999999... - 0.99999 < 0.000001
        // 0.00000001 - 0.000001 < precision
        let upper = decimal.minus(max);
        let lower = decimal.minus(precision);
        if( (lower.gte(constants.ZERO) && lower.lte(precision)) || (upper.gte(constants.ZERO) && upper.lte(precision)) ){
            return result.round()
        }
    }
    return result;
}

export function isDefinedStr(str?: string) {
    return str !== null && str !== undefined && str !== "";
}


export function isValidName(name?: string){
    // TODO: Valid character set
    // Undefined check is redundant, but used as type hint to TS
    if(!isDefinedStr(name) || name == undefined) {
        return false;
    }

    if(name.length > 20) {
        return false;
    }

    let uname = name.toUpperCase();
    // Must start with a letter and contain just non-whitespace chars (\w) and _-
    return /^[A-Z]\w*$/.test(uname);
}

//
// export function groupSelectionPolicy(selection: Boolean[], cells: Cell[]){
//     // Enforce the following rule:
//     // If a group item is selected, either 'all' or 'none' or it's children must be selected
//     // else the group shouldn't be selected.
//     // This enforces absolute click on group rather than bubbled clicks.
//
//     for(let i = 0; i < selection.length; i++){
//         if(selection[i] === true && cells[i].is_group === true){
//             let group = cells[i];
//             let firstChildValue = undefined;
//
//             // Special case to not select group if the list only has a single item
//             // lest that item becomes uneditable.
//             if(group.value.length == 1 && selection[i + 1] == true){
//                 selection[i] = false;
//             }
//             // Offset by one to account for next position in cells array.
//             for(let childIndex = 1; childIndex < group.value.length + 1; childIndex++){
//                 if(childIndex == 1){
//                     // Initialize to the first child's value to see if all else match (all true vs all false)
//                     firstChildValue = selection[i + childIndex]
//                 } else {
//                     if(selection[i + childIndex] !== firstChildValue){
//                         selection[i] = false;
//                     }
//                 }
//             }
//         }
//     }
//     return selection;
// }
//
// export function isEditMode(selected: Boolean[], index: number) {
//     // Check if item at index is the only true value.
//     // Not in edit mode when multiple items are selected.
//     // TODO; Micro optimization - terminate early without all count.
//     if(selected == undefined) {
//         return false;
//     }
//     return selected[index] == true && selected.filter(t => t == true).length == 1
// }



export function formatValue(value: any, valueType?: string) : any {
    if(value !== undefined) {
        if (valueType == undefined) {
            valueType = detectType(value);
        }

        switch (valueType) {
            case constants.TYPE_NUMBER:
                // Replace quotes for Big
                return value.toString().replace('"', "");
            case constants.TYPE_BOOLEAN:
                return value.toString().toUpperCase();
            case constants.TYPE_ARRAY:
                return value.map((v) => {
                    return formatValue(v, undefined);
                }).join(", ");
            case constants.TYPE_STRING:
                return value;
            case constants.TYPE_TABLE:
                return value.map((v) => {
                    return formatValue(v, undefined);
                }).join(", ");
            case constants.TYPE_FORMULA:    // Was unable to evaluate
                return value;
            case constants.TYPE_OBJECT:
                return "Object";
                // return value.expr;
            default:
                return "Unknown " + valueType;
        }
    }

        // TODO: When does this happen?
//        else if (isCell(value)) {
//            return value.evaluate()
//        }


    return value;
}

export function detectType(value: any) {
    if(isFormula(value)){
        return constants.TYPE_FORMULA;
    }

    if(Array.isArray(value)){
        if(value.length > 0 && Array.isArray(value[0])){
            return constants.TYPE_TABLE;
        }
        return constants.TYPE_ARRAY;
    }

    let literal = castLiteral(value);

    if(isString(literal)) {
        return constants.TYPE_STRING;
    }

    if(literal === true || literal === false){
        return constants.TYPE_BOOLEAN;
    }

    if(isNumber(literal)){
        return constants.TYPE_NUMBER;
    }

    // Do this afterwards, because some of the above are also objects of specific type.
    if(typeof value == "object"){
        return constants.TYPE_OBJECT;
    }

    return "";
}

export function toJs(value: any, valueType?: string) {
    if(value == undefined || value == null){
        return value;
    }

    switch(valueType) {
        case constants.TYPE_NUMBER:
            // Replace quotes for Big
            return Number(value);
        case constants.TYPE_BOOLEAN:
            return castBoolean(value);
        case constants.TYPE_STRING:
            // Assuming this has been evaluated.
            return value;
        case constants.TYPE_ARRAY:
            return value.map((v) => {
                let valed = unboxVal(v);
                return toJs(v);
            });
        default:
            return unboxVal(value);
    }
    // case formula should not happen since this method is meant to be used with results.
}

export function diff(original, updated){
    // Return what was added, removed and stayed the same. 
    let added = [];
    let removed = [];
    let same = [];

    // Find missing elements and shared elements.
    original.forEach((el) => {
        if(updated.indexOf(el) != -1){
            same.push(el);
        } else {
            removed.push(el);
        }
    });

    // Elements present only in updated.
    // Same elements are handled in previous loop
    updated.forEach((el) => {
        if(original.indexOf(el) == -1){
            added.push(el);
        }
    })

    return {
        "added": added, 
        "removed": removed, 
        "same": same
    }

}


// https://codepen.io/neoux/pen/OVzMor
export function getCaretCharacterOffsetWithin(element) {
  var caretOffset = 0;
  var doc = element.ownerDocument || element.document;
  var win = doc.defaultView || doc.parentWindow;
  var sel;
  if (typeof win.getSelection != "undefined") {
    sel = win.getSelection();
    if (sel.rangeCount > 0) {
      var range = win.getSelection().getRangeAt(0);
      var preCaretRange = range.cloneRange();
      preCaretRange.selectNodeContents(element);
      preCaretRange.setEnd(range.endContainer, range.endOffset);
      caretOffset = preCaretRange.toString().length;
    }
  } else if ((sel = doc.selection) && sel.type != "Control") {
    var textRange = sel.createRange();
    var preCaretTextRange = doc.body.createTextRange();
    preCaretTextRange.moveToElementText(element);
    preCaretTextRange.setEndPoint("EndToEnd", textRange);
    caretOffset = preCaretTextRange.text.length;
  }
  return caretOffset;
}

export function getCaretPosition() {
  if (window.getSelection && window.getSelection().getRangeAt) {
    var range = window.getSelection().getRangeAt(0);
    var selectedObj = window.getSelection();
    var rangeCount = 0;
    var childNodes = selectedObj.anchorNode.parentNode.childNodes;
    for (var i = 0; i < childNodes.length; i++) {
      if (childNodes[i] == selectedObj.anchorNode) {
        break;
      }
      if (childNodes[i].outerHTML)
        rangeCount += childNodes[i].outerHTML.length;
      else if (childNodes[i].nodeType == 3) {
        rangeCount += childNodes[i].textContent.length;
      }
    }
    return range.startOffset + rangeCount;
  }
  return -1;
}

export function getUnixTimestamp() {
    return Math.round((new Date()).getTime() / 1000);
}
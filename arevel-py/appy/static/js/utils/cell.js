import { typeDefaults } from '../constants.js'

export function getattr(object, attr, fallback) {
    return attr in object ? object[attr] : fallback
}

export function cellGet(cell, attr) {
    if(attr in cell){
        return cell[attr]
    }
    
    let type = cell["type"];                        // Assume this always exists

    if(type in typeDefaults && attr in typeDefaults[type]){
        return typeDefaults[type][attr];
    }
    return typeDefaults["default"][attr];
}


export function formatCellOutput(cell) {
    let output = cellGet(cell, "value");
    if(output === undefined || output === null){
        return ""
    }
    else if(output === true) {
        return "True"
    } 
    else if(output === false) {
        return "False"
    } else {
        return "" + output
    }
}


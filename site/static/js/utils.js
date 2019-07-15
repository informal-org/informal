import { typeDefaults } from './constants.js'

export function inc(x) {
    return x + 1
}

export function dec(x) {
    return x - 1
}

export function listToMap(list, key="id"){
    var resultMap = {}
    for(var i = 0; i < list.length; i++){
        let item = list[i];
        resultMap[item[key]] = item
    }
    return resultMap
}

export function apiPost(url = '', data = {}) {
    return fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data), // body data type must match "Content-Type" header
    })
    .then((response) =>{
        if(response.ok) {
            return response.json();
        }
        throw new Error('Network response was not ok.');
    })
}

export function getIndex(arr, item) {
    // Equivalent to indexOf, but using value equality rather than pointer equality
}

export function getattr(object, attr, fallback) {
    return attr in object ? object[attr] : fallback
}

export function cellGet(cell, attr) {
    if(attr in cell){
        return cell[attr]
    }
    
    let type = cell["type"];                        // Assume this always exists
    if(attr === "width") {
        if(cell["error"]) {
            return 2;
        } else if(cell["output"] && cell["output"].toString().length > 10){
            return 2;
        }
    } else if(attr == "height") {
        if(cell["error"] && cell["error"].length > 10) {
            return 2;
        }
    }

    if(type in typeDefaults && attr in typeDefaults[type]){
        return typeDefaults[type][attr];
    }
    return typeDefaults["default"][attr];
}


export function formatCellOutput(cell) {
    let output = cellGet(cell, "output");
    if(output === undefined){
        return " "
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
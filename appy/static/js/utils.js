import { typeDefaults } from './constants.js'
import { v4 as uuidv4 } from 'uuid';

// The alphabet from the python version
const SHORTUUID_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const SHORT_PAD_LEN = 22;   // Pre-computed expected shortuuid length

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

export function getCookie(name) {
    var cookieValue = null;
    if (document.cookie && document.cookie != '') {
        var cookies = document.cookie.split(';');
        for (var i = 0; i < cookies.length; i++) {
            var cookie = cookies[i].trim();
            // Does this cookie string begin with the name we want?
            if (cookie.substring(0, name.length + 1) == (name + '=')) {
                cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
            break;
        }
    }
    }
    return cookieValue;
}

export function apiPost(url = '', data = {}) {
    return fetch(url, {
        method: 'POST',
//        mode: "no-cors",    // TODO: TEMPORARY WORKAROUND FOR LOCALHOST RUST. DISABLE THIS!!
        headers: {
            'Content-Type': 'application/json',
            'X-CSRFToken': getCookie('csrftoken')
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

export function apiPatch(url = '', data = {}) {
    console.log("PUT " + url);
    console.log(data)
    return fetch(url, {
        method: 'PATCH',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRFToken': getCookie('csrftoken')
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

function encodeID(number) {
    // Parameter - Number - BigInt
    var output = "";
    var alpha_len = BigInt(SHORTUUID_ALPHABET.length)
    
    while (number > 0) {
        var div = number / alpha_len;   // Fraction will be truncated
        var base_index = number % alpha_len;
        number = div;
        output += SHORTUUID_ALPHABET[base_index.valueOf()];
    }

    // Add padding to account for any fractional truncation
    for(var i = 0; i < SHORT_PAD_LEN - output.length; i++) {
        output += SHORTUUID_ALPHABET[0];
    }
    return output
}

export function genID() {
    var buffer = new Array();
    uuidv4(null, buffer, 0); 
    var uuid_hex = "0x";
    buffer.forEach((b) => {
        uuid_hex += b.toString(16);
    });
    var number = BigInt(uuid_hex);
    return encodeID(number);
}


export function mapToArray(m) {
    // Serialize a map to an array for storage
    return [m.keys(), m.values()]
}

export function arrayToMap(arr) {
    // Convert key list and value list to the tuple format accepted by Map
    return Map(zip(arr[0], arr[1]))
}

function noopZip(val1, val2) {
    return [val1, val2]
}

export function zip(arr1, arr2, zipper=noopZip) {
    return arr1.map((value, index) => zipper(value, arr2[index]) )
}
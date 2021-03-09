// a + b
export function union(a, b) {
    return new Set([...a, ...b])
}

// a - b
export function difference(a, b) {
    return new Set([...a].filter(ai => !b.has(ai)));
}

// Elements contained in both sets
export function intersection(a, b) {
    return new Set([...a].filter(ai => b.has(ai)))
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


export function listToMap(list, key="id"){
    var resultMap = {}
    for(var i = 0; i < list.length; i++){
        let item = list[i];
        resultMap[item[key]] = item
    }
    return resultMap
}

export function delta(list) {
    // Given a list, return a list of delta
    let result = [];
    for(var i = 1; i < list.length; i++) {
        result.push(list[i] - list[i-1])
    }
    return result
}

export function deltaDiv(list) {
    let result = [];
    for(var i = 1; i < list.length; i++) {
        let step_div = list[i-1] != 0 ? list[i] / list[i-1] : null;
        result.push(step_div)
    }
    return result
}

export function getStep(list) {
    if(list.length == 0) { return false }
    let val = list[0];
    for(var i = 1; i < list.length; i++) {
        let elem = list[i];
        if(elem === null || val !== elem) {
            return false;
        }
    }
    return val
}
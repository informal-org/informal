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

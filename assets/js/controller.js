import parseExpr from "./expr.js"

export function modifySize(cell, dimension, min, max, amt) {
    if(cell){
        let newSize = cell[dimension] + amt;
        if(newSize >= min && newSize <= max){
            cell[dimension] = newSize;
        }
    }
    return cell
}


export function parseEverything(cells) {
    let data = {}
    data.body = {}
    for(var id in cells){
        let cell = cells[id];
        if(cell.input.trim() == ""){
            // TODO: Also need to check for if any dependent cells. 
            // So that it's valid to have cells with space            
            continue
        }
        data.body[cell.id] = {
            id: cell.id,
            input: cell.input,
            parsed: parseExpr(cell.input)
        }
    }
    return data
}

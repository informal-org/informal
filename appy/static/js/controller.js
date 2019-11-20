import { cellGet } from "./utils.js"

export function modifySize(cell, dimension, min, max, amt) {
    if(cell){
        let newSize = cellGet(cell, dimension) + amt;
        if(newSize >= min && newSize <= max){
            cell[dimension] = newSize;
        }
    }
    return cell
}

export function parseEverything(cells) {
    let data = {}
    data.body = []
    for(var id in cells){
        let cell = cells[id];
        let cellInput = cellGet(cell, "input");
        if(cellInput.trim() == ""){
            // TODO: Also need to check for if any dependent cells. 
            // So that it's valid to have cells with space            
            continue
        }
        data.body.push({
            id: cell.id,
            name: cell.name,
            input: cellInput,
        });
    }
    return data
}

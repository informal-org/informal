import { cellGet } from "./utils"



export function parseEverything(cells) {
    let data = {}
    data.body = []
    for(var id in cells){
        let cell = cells[id];
        let cellInput = cellGet(cell, "expr");
        if(cellInput == undefined || cellInput.trim() == ""){
            // TODO: Also need to check for if any dependent cells. 
            // So that it's valid to have cells with space            
            continue
        }
        // Filter out empty parameters
        let params = Array.isArray(cell.params) ? cell.params.filter(param => param !== undefined && param !== "") : [];
        data.body.push({
            id: cell.id,
            name: cell.name,
            expr: cellInput,
            params: params
        });
    }
    return data
}


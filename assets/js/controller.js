export function modifySize(cell, dimension, min, max, amt) {
    if(cell){
        let newSize = cell[dimension] + amt;
        if(newSize >= min && newSize <= max){
            cell[dimension] = newSize;
        }
    }
    return cell
}

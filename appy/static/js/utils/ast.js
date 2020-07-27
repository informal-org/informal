
export function findMinStart(node) {
    let min = node.char_start;
    if(node.left) {
        let left_start = findMinStart(node.left)
        min = left_start < min ? left_start : min
    }
    if(node.right) {
        let right_start = findMinStart(node.right);
        min = right_start < min ? right_start : min
    }
    if(node.value) {
        for(var i = 0; i < node.value.length; i++){
            let val_start = findMinStart(node.value[i]);
            min = val_start < min ? val_start : min
        }
    }
    return min
}


export function findMaxEnd(node) {
    let max = node.char_end;
    if(node.left) {
        let left_end = findMaxEnd(node.left)
        max = left_end > max ? left_end : max
    }
    if(node.right) {
        let right_end = findMaxEnd(node.right);
        max = right_end > max ? right_end : max
    }
    if(node.value) {
        for(var i = 0; i < node.value.length; i++){
            let val_start = findMaxEnd(node.value[i]);
            max = val_start > max ? val_start : max
        }
    }    
    return max
}
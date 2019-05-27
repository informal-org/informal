/**
 * Computes the CSS Grid flow rules in javascript to figure out where cells would be layed out.
 * Lays things out based on the specified widths and heights. 
 * Defined declaratively for simplicity and to work well with react.
 * Currently set to work with grid-auto-flow: row; you're doing a dense fill, things may shift around. 
 * Uncomment alternative implementation below.
 * 
 * Beware: Here be dragons. I've verified this function as much as possible, but be careful modifying this.
 * 
 * Arguments:
 * cells: List of cells, with cell.display.width, cell.display.height attributes.
 * numCols: Number of columns in the grid. Should match CELL_MAX_WIDTH unless the view is responsive.
 */
export default function computeGridPositions(cells, numCols){
    var numRows = cells.length;
    // Index: [y][x] - so we can access things row by row.
    var grid = new Array(numRows);
    
    // Pre-fill array with the empty sentinels.
    // Might be possible to do this along with the bottom steps, but makes it more complex.
    const totalCells = numCols * numRows;
    const EMPTY_CELL = "XX";
    for(var y = 0; y < numRows; y++){
        let row = new Array(numCols);
        for(var x = 0; x < numCols; x++){
            row[x] = EMPTY_CELL;
        }
        grid[y] = row;
    }

    // These indexes allow us to resume the search where we left off after positioning a single block
    var nextFreeX = 0;
    var nextFreeY = 0;
    for(var i = 0; i < numRows; i++){
        const cellID = cells[i].id;
        const width = cells[i].display.width;
        const height = cells[i].display.height;

        // Search for the next open spot where this would fit.
        var searchY = nextFreeY;
        var searchX = nextFreeX;
        let found = false;
        while(!found){
            // Heuristic: If the row is not long enough for a cell of this width, go to next row.
            if(width > (numCols - searchX)){
                searchX = 0;
                searchY++;
                continue
            }

            // Terminal: If you reach end of grid, give up.
            if(searchY >= numRows) {
                console.log("Could not find position to fit");
                break;
            }

            // Check if all the cells are free, in both x and y direction.
            found = true;
            for(var verifyY = searchY; verifyY < searchY + height; verifyY ++){
                for(var verifyX = searchX; verifyX < searchX + width; verifyX++){
                    // If you run into any occupied cells, move on to next iter of search.
                    if(grid[verifyY][verifyX] !== EMPTY_CELL){
                        console.log("Found blocker");
                        found = false;
                        break;
                    }
                }
            }

            if(found){
               // Re-iterate over the verified block and mark those cells as occupied.
                var verifyX;
                var verifyY;
                for(verifyY = searchY; verifyY < searchY + height; verifyY ++){
                    for(verifyX = searchX; verifyX < searchX + width; verifyX++){
                        console.log("Filling");
                        // If you run into any occupied cells, move on
                        grid[verifyY][verifyX] = cellID;

                        // Begin: grid-auto-flow: dense;
                        // Uncomment this block if you change the auto-flow property.
                        // This would continue trying to allocate cells to any free spots to be densely packed,
                        // causing things to be re-arranged as a result.
                        // if(verifyX == nextFreeX && verifyY == nextFreeY){
                        //     // Skip ahead for future searches.
                        //     nextFreeX++;
                        //     if(nextFreeX >= numCols){
                        //         nextFreeX = 0;
                        //         nextFreeY++;
                        //     }
                        // }
                        // End - grid-auto-flow: dense;
                    }
                }

                // Begin: grid-auto-flow: row;
                // Comment out this block if doing dense. This skips to the next free spot, leaving spaces as needed.
                nextFreeY = searchY; // Min cell height of 1 is expected, but keep pointing to same row.
                nextFreeX = searchX+width; // Min cell width of 1 is expected, so this is alredy pointing to next node.
                if(nextFreeX >= numCols){
                    nextFreeX = 0;
                    nextFreeY++;
                }
                // End - grid-auto-flow: row;
                break;
            } else {
                // Go to the next search spot
                searchX++;
                if(searchX >= numCols){
                    searchX = 0;
                    searchY++;
                }
            }
        }
    }
    console.log(grid);
    return grid;
}

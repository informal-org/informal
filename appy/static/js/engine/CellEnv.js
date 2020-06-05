import { Cell } from "./Cell";
import { addDependency } from "./order.js"
import { traverseDown, traverseUp } from "./iter.js"

export class CellEnv {
    // Analogous to an AST. Contains metadata shared across cells.
    constructor() {
        // Maps use IDs as keys so they can be defined independent of cell creation

        // Root cell node
        this.root = undefined;
        // Cell ID -> Raw cell details
        this.raw_map = undefined;        
        // Cell ID -> Cell
        this.cell_map = {};
        // Cell ID -> Set of dependency IDs
        this.dependency_map = {};
        // Cell ID -> Set of nodes that use it. Inverse of dependency_map.
        this.usage_map = {};
        // Cell ID -> subset of cell's dependencies that are circular.
        this.cyclic_deps = {};
        // Computed evaluation order
        this.eval_order = [];

        // Bind this to the object for any functions called in higher-order traversals
        this.createCell = this.createCell.bind(this);
    }
    create(raw_map, root_id) {
        this.raw_map = raw_map;
        this.root = this.createCell(root_id);
        return this.root;
    }
    createCell(cell_id, parent) {
        console.log("createCell helper: " + cell_id + " : " + parent);
        let env = this;
        let raw_cell = env.getRawCell(cell_id);
        console.log(this.raw_map);
        console.log(raw_cell);
        
        let cell = new Cell(raw_cell, parent, env);

        // Recursively create all children, with cell as parent.
        [cell.params, cell.body] = traverseDown(raw_cell, env.createCell, cell);

        if(raw_cell.depends_on) {
            raw_cell.depends_on.forEach((dep) => {
                addDependency(env, cell.id, dep)
            })
        }

        return cell
    }
    static getDefaultSet(map, key) {
        // Lookup key in map with python defaultdict like functionality.
        if (!map.hasOwnProperty(key)) {
            map[key] = new Set();
        }
        return map[key];
    }

    getRawCell(id) {
        return this.raw_map[id];
    }
    getCell(id) {
        return this.cell_map[id];
    }
    getDependsOn(cell_id) {
        return CellEnv.getDefaultSet(this.dependency_map, cell_id);
    }
    getUsedBy(cell_id) {
        return CellEnv.getDefaultSet(this.usage_map, cell_id);
    }

}

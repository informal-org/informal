import { Cell } from "./Cell";
import { addDependency } from "./order.js"
import { traverseDown, traverseDownCell, traverseUp } from "./iter.js"
import { parseExpr } from "./parser"
import { astToJs } from "./generator";

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
        this.parseAll = this.parseAll.bind(this);
        this.exprAll = this.exprAll.bind(this);
        this.emitJs = this.emitJs.bind(this);
        this.create = this.create.bind(this);
    }
    create(raw_map, root_id) {
        this.raw_map = raw_map;
        this.root = this.createCell(root_id);
        return this.root;
    }
    createCell(cell_id, parent) {
        let env = this;
        let raw_cell = env.getRawCell(cell_id);

        let cell = new Cell(raw_cell, parent, env);
        env.cell_map[cell.id] = cell;

        // Recursively create all children, with cell as parent.
        [cell.params, cell.body] = traverseDown(raw_cell, env.createCell, cell);

        if(raw_cell.depends_on) {
            raw_cell.depends_on.forEach((dep) => {
                addDependency(env, cell.id, dep)
            })
        }

        return cell
    }
    
    parseAll(cell_id) {
        let env = this;
        let raw_cell = env.getRawCell(cell_id);
        let cell = env.getCell(cell_id);

        try {
            cell.parsed = parseExpr(cell.expr);
        }
        catch(err) {
            cell.error = err.message
        }

        traverseDown(raw_cell, env.parseAll);
    }

    exprAll(cell) {
        let env = this;

        if(cell.error) { return }
        if(cell.id in env.cyclic_deps) {
            return
        }

        cell.expr_node = astToExpr(cell, cell.parsed);
        traverseDownCell(cell, env.exprAll);
    }

    emitJs(cell, target) {
        let env = this;
        
        if(cell.error) { return }
        if(cell.id in env.cyclic_deps) { 
            target.emitCellError(cell, "CyclicRefError")
            return target
        }

        target.emitTry();
        let result = cell.expr_node.emitJS(target)
        if(result) {
            target.emit(target.declaration(cell.getCellName(), result))
            target.emitCellResult(cell);
        }
        
        target.emitCatchAll(this);

        traverseDownCell(cell, env.emitJs, target);
        return target
    }

    findDependencies(cell_id) {
        
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

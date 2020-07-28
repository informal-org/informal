const hamt = require('hamt');

export class Cell {
    constructor(cell, parent, env) {
        env.cell_map[cell.id] = this;
        this.env = env;
        this.parent = parent;

        this.id = cell.id;
        this.type = cell.type;
        this.name = cell.name;
        this.expr = cell.expr;

        // Cell is the only parent for params and body, so recursively init those.
        this.param_ids = new Set(cell.params);
        this.params = [];
        
        this.body_ids = new Set(cell.body);
        this.body = [];
        this.ordered_body = [];

        // Mutable execution state.
        this._num_pending_deps = undefined;
        // Numerical index of evaluation order in total ordering
        this._eval_index = -1;
        this._depend_count = 0;

        this.parsed = {};
        this.expr_node = null;
        this.error = null;
        this.result = null
        this.namespace = hamt.empty;
    }

    toString() {
        return "Cell(" + this.id + "," + this.name + ")";
    }

    getCellName() {
        return this.name ? this.name : "__" + this.id;
    }

}

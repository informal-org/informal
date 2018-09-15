import * as util from '../utils';
import * as constants from "../constants"
import {isValidName, castLiteral, detectType} from "../utils";

import {parseFormula, evaluateExpr, evaluateStr, getDependencies, getStrDependencies} from "./expr"

// import * as getParams from 'get-parameter-names';

import {BUILTIN_FN} from './stdlib';
// var get = require('get-parameter-names')

export class Value {
    id: string;
    // @ts-ignore
    private _name: string;
    private _expr: any;

    type: string = "value";

    depends_on: Value[] = [];
     // Used in the initial stage when some names aren't defined till later.
    _unresolved_dependencies: string[] = [];
    used_by: Value[] = [];

    parent: Group | null = null;
    // @ts-ignore
    engine: Engine;

    errors: string[] = [];

    _parsed = null;
    _result = null;
    _is_stale = true;
    _expr_type: string = "";   // One of FORMULA, BOOL, STR, NUM
    _result_type: string = "";  // Usually the same as _expr_type, except when it's a function.


    // FOR GROUPS
    // Name => Value
    name_map: {
        [index: string]: Value
    } = {};

    // ID => Value
    id_map:{
        [index: string]: Value
    } = {};

    stale_nodes: Value[];
    

    constructor(value: any, parent?: Group, name?: string) {
        this.id = util.generate_random_id();
        if(parent !== undefined){
            this.engine = parent.engine;
            if(parent instanceof Group){
                parent.addChild(this);
            } else {
                this.parent = parent;
            }

            if(this.engine){
                this.engine.num_cells++;
                this.engine.all_cells.push(this);
            }
        }

        // @ts-ignore: string | undefined
        this.name = name;
        this.expr = value;
    }

    addDependency(other: Value) {
        if(other === null || other === undefined){
            return
        }
        this.depends_on.push(other);
        other.used_by.push(this);
    }

    removeDependency(other: Value) {
        if(other === null || other === undefined){
            return
        }
        // @ts-ignore: Remove is a custom method
        this.depends_on.remove(other);
        // @ts-ignore: Remove is a custom method
        other.used_by.remove(this);
    }

    updateDependencies(deps: Value[]){
        if(deps === null || deps === undefined){
            return;
        }
        // Find what changed and then add or remove.
        let dependency_changes = util.diff(this.depends_on, deps);
        dependency_changes.removed.forEach((el) => this.removeDependency(el));
        dependency_changes.added.forEach((el) => this.addDependency(el));
    }

    get name(): string {
        return this._name;
    }

    set name(newName: string) {
        if(util.isDefinedStr(this._name) && newName == this._name){
            return;
        }
        let NAME_ERROR = "Variable names should start with a letter and can only contain letters, numbers, _ and -";

        // newName == undefined is redundant: hint for typescript
        if(!util.isDefinedStr(newName) || newName == undefined) {
            if(this.parent !== null){
                newName = this.parent.generateName();
            } else {
                // this.addError(NAME_ERROR);
                return;
            }
        }

        if(isValidName(newName) && this._nameAvailable(newName)){
            if(this.parent != null ){
                this.parent.unbind(this);
                this.parent.bind(newName, this);
            }

            this._name = newName;
            this.removeError(NAME_ERROR);
        } else {
            this.addError(NAME_ERROR)
        }

    }

    _nameAvailable(name: string){
        // Check if a name is available in parent scope.
        return this.parent == null || !(name in this.parent.name_map);
    }

    addError(message: string){
        if(this.errors.indexOf(message) == -1){ // Only add non-existent errors.
            this.errors.push(message)
        }
    }

    removeError(prefix: string){
        // Remove by prefix
        this.errors = this.errors.filter((err) => !err.startsWith(prefix));
    }

    get expr(){
        return this._expr;
    }

    set expr(newValue: string){
        this._expr = newValue;
        this._expr_type = util.detectType(newValue);
        if(this._expr_type == constants.TYPE_FORMULA){
            this._parsed = parseFormula(this.expr);
            this.updateDependencies(getDependencies(this._parsed, this));
        } else {
            this._parsed = null;
            if (this._expr_type == constants.TYPE_STRING) {
                this.updateDependencies(getStrDependencies(this.expr, this))
            } 
        }
        this.markStale();
        this._setExprHook(newValue);

        // todo - OTHER TYPES, ESP STRING
    }

    _setExprHook(newValue: string){
        // Pass - hook for child classes to do followup actions
    }

    exprString() {
        return util.formatValue(this._expr, this._expr_type);
    }

    toString() {
        // return util.formatValue(this._result, this._result_type);
        return util.formatValue(this.evaluate(), this._result_type);
    }

    // To javascript for interop
    toJs() {
        return util.toJs(this._result, this._result_type);
    }

    _doEvaluate(){
        /*
        // Does the core of evaluate without any of the caching layers.
        // Can be overwritten.
         */

        let EVAL_ERR_PREFIX = "Evaluation error: "
        if(this.expr == undefined || this.expr == null){
            return null;
        }
        this._expr_type = detectType(this.expr);

        if(this._expr_type == constants.TYPE_FORMULA){
            // Is formula
            try {
                let result = evaluateExpr(this._parsed, this);
                this.removeError(EVAL_ERR_PREFIX);
                return result;
            } catch(err) {
                // TODO: Propagate this error to other dependent cells -
                // Else their value could be messed up as well...
                let errMessage = err.message ? err.message : err.toString();
                errMessage = EVAL_ERR_PREFIX + errMessage.replace("[big.js]", "");
                this.addError(errMessage);
                console.log(err);
                // TODO: Return value
                return this.expr;
            }
        }
        else if(this._expr_type == constants.TYPE_STRING) {
            console.log("Eval str")
            return evaluateStr(this.expr, this);
        } else {
            // Numbers and booleans
            return castLiteral(this.expr);
        }
        return null;
    }

    // @ts-ignore - return type any.
    evaluate() {
        // Return cached.
        return this._result;
    }

    // Does the actual evaluation asyncrhronously
    tick() {
        if(this._is_stale){
            // Re-evaluate and set this._result;
            this._result = this._doEvaluate();
            this._result_type = detectType(this._result);
            this.markClean();
        }
    }

    markStale(){
        if(!this._is_stale){
            this._is_stale = true;
            if(this.engine !== undefined){
                this.engine.stale_nodes.push(this);
            }
            
            // Touch all of the cells that depend on this as well.
            this.used_by.forEach((val) => val.markStale());
        }
    }

    markClean(){
        if(this._is_stale){
            this._is_stale = false;
            // @ts-ignore: Remove is a custom method.
            if(this.engine !== undefined){
                this.engine.stale_nodes.remove(this);
            }
                
        }
    }

    destruct(){
        // Remove child.
        if(this.parent){
            this.parent.removeChild(this);
        }
        while(this.used_by.length > 0){
            this.used_by[this.used_by.length - 1].removeDependency(this);
        }

        this.engine.all_cells.remove(this);
        // Don't subtract num_cells, we want it to always increase to avoid naming conflict.
    }


    lookup(name: string, exclude?: Group) {
        if(this.parent == null){
            return [];
        }
        if(exclude !== undefined && this.parent.id == exclude.id){
            return [];
        }
        if(this._result !== null && this._result.type === "table"){
            console.log("Resolve is defined")
            let resolution = this._result.lookup(name, this);
            if(resolution.length > 0) {
                return resolution;
            }
        }

        // TODO: Support fully qualified names. In which case, this would remove part of path?
        return this.parent.lookup(name);
    }

    resolve(name: string) {
        // Heuristic: In case of multiple matches, resolve to the node in our dependency list.
        let options = this.lookup(name);
        // Find the options we depend on.
        if(options.length > 0){
            let deps = this.depends_on;
            let found = options.filter((opt) => deps.indexOf(opt) != -1);
            // Return first dependency or just first matched name. IDC.
            return found.length > 0 ? found[0] : options[0];
        }
        return null;
    }

    isArrResult(){
        return this._result_type == constants.TYPE_ARRAY;
    }

    bind(name: string, value: Value){
        let uname = name.toUpperCase();
        if(!isValidName(uname)){
            throw Error("Invalid name");
        }
        if(uname in this.name_map){
            throw Error("Name is already being used");
        }

        this.name_map[uname] = value;
    }

    unbind(value: Value){
        if(value == null || value.name == null || value.name == ""){
            return;
        }

        let uname = value.name.toUpperCase();
        if(this.name_map[uname] == value){
            delete this.name_map[uname];
        }
    }

    generateName(){
        let length: number = this.expr.length;
        length = length + (this.engine ? this.engine.num_cells : 0);
        for(let i = length; i < (length * 2) + 2; i++){
            let name = "Cell" + i;
            if(!(name in this.name_map)){
                return name;
            }
        }
        return ""
    }
    
    isRootChild() {
        return this.parent && this.engine && this.parent == this.engine.root;
    }

    isRoot() {
        return this.engine && this.engine.root === this;
    }
}

// Essentially just a list of values
export class Group extends Value {

    type: string = "group";

    _expr_type = constants.TYPE_ARRAY;
    _result_type = constants.TYPE_ARRAY;

    constructor(value?: Array<Value>, parent?: Group, name?: string) {
        // @ts-ignore
        super([], parent, name);
        if(value !== undefined){
            value.forEach((val) => {
                this.addChild(val);
            })
        }
    }

    _doEvaluate(){
        // return this.expr.map((val: Value) => val.evaluate());
        return this.expr
    }

    destruct(){
        super.destruct();

        while(this.expr.length > 0){
            // Pop elements from end of list
            // @ts-ignore: it is an array. pop does exist.
            let cell = this.expr.pop();
            if(cell != undefined){
                cell.destruct();
            }
        }
    }

    addChild(child: Value) {
        child.parent = this;
        // @ts-ignore: is array. push exists.
        this.expr.push(child);
        this.id_map[child.id] = child;

        if(child.name !== undefined){
            this.bind(child.name, child);
        }
    }

    removeChild(child: Value){
        child.parent = null;
        // @ts-ignore: Remove is a custom method
        this.expr.remove(child);
        delete this.id_map[child.id];
        this.unbind(child);
    }

    _childLookup(uname: string, exclude?: Group){
        let matches: Value[] = [];
        let thisNode: Group = this;
        this.expr.forEach((child) => {
            if(exclude === undefined || child.id != exclude.id){
                matches = matches.concat(child.lookup(uname, thisNode));
            }
        });
        return matches;
    }

    _parentLookup(uname: string, exclude?: Group){
        let matches: Value[] = [];
        let thisNode: Group = this;

        if(this.parent !== null && (exclude === undefined || this.parent.id !== exclude.id)) {
            matches = matches.concat(this.parent.lookup(uname, thisNode));
        }
        return matches;
    }


    lookup(name: string, exclude?: Group) {
        /*
         Lookup a name in an environment.
         Return a list of found Values.
         Priority - lookup in self, then in children, then in parent.

         Exclude specifies Values not to search in (to prevent infinite recursion).
        */
        // Lookup name in direct environment
        if(exclude !== undefined && this.id === exclude.id) {
            return [];
        }

        let uname = name.toUpperCase().trim();
        if(uname in this.name_map){
            return [this.name_map[uname]];
        }

        let nameResolutions: Value[] = [];
        // nameResolutions = nameResolutions.concat(this._childLookup(uname, exclude));
        nameResolutions = nameResolutions.concat(this._parentLookup(uname, exclude));
        //nameResolutions = nameResolutions.concat(this._resultLookup(uname, exclude));
        return nameResolutions;
    }


}

//
// // TODO
export class Table extends Group {
    // Can be used for single objects, as a map, or for more complex tables.
    // Distinction from above is multiple lists. It's more of a matrix.
    // So it's a list of groups. Neat.

    // expr: Group[] = [];
    type: string = "table";

    _expr_type = constants.TYPE_ARRAY;
    _result_type = constants.TYPE_ARRAY;

    getColumnNames() {
        return this.expr.map((grp: Group) => grp.name);
    }

    getColumns() {
        return this.expr;
    }

    numRows() {
        return this.expr !== [] ? this.expr[0].expr.length : 0;
    }

    getRow(index: number) {
        // let row = [];   // Use an array rather than a dictionary here to preserve ordering.
        // this.expr.forEach((grp: Group) => {
        //     row.push({
        //         "key": grp.name, 
        //         "value": grp.expr[index].evaluate()
        //     });
        // })
        return this.expr.map((grp: Group) => grp.expr[index]
        //.evaluate()
        );
        //return row;
    }

    getRows(){
        let rows = [];
        for(let i = 0; i < this.numRows(); i++){
            rows.push(this.getRow(i));
        }
        return rows;
    }

    _doEvaluate(){
        // It's returned in a row oriented format so we can apply row filtering to it easily using WHERE.
        // return this.getRows();
        return this.expr
    }
}

export class FunctionCall extends Value {
    type = "func";

    // Expr = function name

    // List of parameters
    args: Value[] = [];

    availableFunctions() {
        return Object.keys(BUILTIN_FN);
    }

    isValidFn(){
        return this._expr !== undefined && this._expr !== "" && this.expr in BUILTIN_FN;
    }

    getArgNames() {
        return this.isValidFn() ? BUILTIN_FN[this.expr].args : [];
    }

    _setExprHook(newValue: string){
        let thisCell = this;
        
        this.args = this.getArgNames().map((name) => {
            let v = new Value("", thisCell, name);
            thisCell.addDependency(v);
            return v;
        })
        this.evaluate();
    }

    _doEvaluate(){
        if(this.isValidFn()){
            try{
                let stdfn =  BUILTIN_FN[this.expr];
                let parameters = this.args.map((arg) => {
                    arg.evaluate();
                    return arg.toJs();
                });
                return stdfn.fn.apply(null, parameters);
            } catch(err) {
                console.log("Evaluation error for fn");
                console.log(err);
            }

        }
        return "";
    }

    getDescription() {
        return this.isValidFn() ? BUILTIN_FN[this.expr].description : "";
    }
}

export class Engine {
    root: Group;

    stale_nodes: Value[] = [];
    num_cells = 0;

    all_cells = [];

    constructor() {
        this.root = new Group();
        this.root.engine = this;
        this.root.name = "ROOT";

        let thisNode = this;

        let tickFn = window.setInterval(function(){
            /// call your function here
            thisNode.tick();
          }, 200);
          
    }

    tick(){
        this.all_cells.forEach(cell => {
            cell.tick();
        });
    }

    //
    // // TODO;
    // rename(value: Value, name: string) {
    //     if(isValidName((name))){
    //         value.name = name;
    //     }
    // }
    //
}
import * as util from '../utils';
import * as constants from "../constants"
import {isValidName} from "../utils";



export class Value {
    id: string;
    name: string;

    type: string = "value";
    expr: string = "";

    depends_on: Value[] = [];
     // Used in the initial stage when some names aren't defined till later.
    _unresolved_dependencies: string[] = [];
    used_by: Value[] = [];

    parent: Group | null = null;
    engine: Engine;

    errors: string[] = [];

    _parsed = null;
    _result = null;
    _is_stale = true;
    _expr_type: string = "";   // One of FORMULA, BOOL, STR, NUM
    _result_type: string = "";  // Usually the same as _expr_type, except when it's a function.

    constructor(value: string, engine: Engine, parent?: Group, name?: string) {
        this.engine = engine;
        this.id = util.generate_random_id();
        this.setValue(value);
        this.parent = parent !== undefined ? parent : null;

        this.rename(name);

        if(parent !== undefined){
            parent.id_map[this.id] = this;
        }
    }


    addDependency(other: Value) {
        this.depends_on.push(other);
        other.used_by.push(this);
    }

    removeDependency(other: Value) {
        if(this.depends_on.indexOf(other) != -1){
            this.depends_on.splice(this.depends_on.indexOf(other), 1);
        }
        if(other.used_by.indexOf(this) != -1){
            other.used_by.splice(other.used_by.indexOf(this), 1);
        }

    }

    rename(newName?: string) {
        if(newName == this.name){
            return;
        }
        let NAME_ERROR = "Variable names should start with a letter and can only contain letters, numbers, _ and -";

        if((newName === "" || newName === undefined)) {
            if(this.parent !== null){
                newName = this.parent.generateName();
            } else {
                this.addError(NAME_ERROR);
                newName = "";
            }
        }


        if(isValidName(newName) && (this.parent == null || !(newName in this.parent.name_map))){

            if(this.parent != null){
                this.parent.unbind(this);
                this.parent.bind(newName, this);
            }

            this.name = newName;
            this.removeError(NAME_ERROR);

        } else {
            this.addError(NAME_ERROR)
        }
    }

    addError(message: string){
        if(this.errors.indexOf(message) == -1){
            this.errors.push(message)
        }
    }

    removeError(prefix: string){
        // Remove by prefix
        this.errors = this.errors.filter((err) => !err.startsWith(prefix));
    }

    setValue(newValue: string) {
        // TODO: parse and set dependencies.
        this.expr = newValue;
        this._expr_type = util.detectType(newValue);
        if(this._expr_type == constants.TYPE_FORMULA){
            this._parsed = parseFormula(this.expr, this.engine);
        } else {
            this._parsed = null;
        }

        // todo - OTHER TYPES, ESP STRING
    }

    toString() {
        return util.formatValue(this.expr, this._expr_type);
    }

    // To javascript for interop
    toJs() {
        // TODO: This should be done with result
        return util.toJs(this.expr, this._exprtype);
    }

    _doEvaluate(){
        /*
        // Does the core of evaluate without any of the caching layers.
        // Can be overwritten.
         */


        let EVAL_ERR_PREFIX = "Evaluation error: "
        if(this.expr == undefined || this.expr == null){
            return undefined;
        }

        if(this._expr_type == constants.TYPE_FORMULA){
            // Is formula
            try {
                let result = evaluateExpr(this._parsed, this.engine);
                this.removeError(EVAL_ERR_PREFIX);
                return result;
            } catch(err) {
                // TODO: Propagate this error to other dependent cells -
                // Else their value could be messed up as well...

                this.addError(EVAL_ERR_PREFIX + err.message.replace("[big.js]", ""))
                // TODO: Return value
                return this.expr;
            }
        }
        else if(this._expr_type == constants.TYPE_STRING) {
            return evaluateStr(this.expr, this.engine);
        } else {
            // Numbers and booleans
            return castLiteral(this.expr);
        }

    }

    // @ts-ignore - return type any.
    evaluate() {
        if(this._is_stale){
            // Re-evaluate and set this._result;
            return this._doEvaluate();
        }

        // Return cached.
        return this._result;
    }

    markStale(){
        if(!this._is_stale){
            this._is_stale = true;
            // Touch all of the cells that depend on this as well.
            this.used_by.forEach((val) => val.markStale());
        }
    }

    destruct(){
        // Remove child.
        if(this.parent){
            this.parent.removeChild(this);
        }
        // TODO: Remove it as a dependent for all cells this depends on.
        // Error any cells still using this.
    }


    lookup(name: string, exclude?: Value) {
        if(this.parent == null){
            return [];
        }
        if(exclude !== undefined && this.parent.id == exclude.id){
            return [];
        }
        // TODO: Support fully qualified names. In which case, this would remove part of path?
        return this.parent.lookup(name);
    }

}

// Essentially just a list of values
export class Group extends Value {
    // Name => Value
    name_map: {
        [index: string]: Value
    } = {};

    // ID => Value
    id_map:{
        [index: string]: Value
    } = {};

    stale_nodes: Value[];

    expr : Value[] = [];

    type: string = "group";

    constructor(engine: Engine, parent?: Group, name?: string) {
        // @ts-ignore
        super([], engine, parent, name);
    }

    lookup(name: string) : Value | undefined {
        let uname = name.toUpperCase();
        if(uname in this.name_map){
            return this.name_map[uname];
        }
        if(this.parent !== null){
            return this.parent.lookup(name)
        }
        return undefined;
    }

    _doEvaluate(){
        return this.expr;
    }

    destruct(){
        super.destruct();
        while(this.expr.length > 0){
            // Pop elements from end of list
            this.expr.pop().destruct();
        }
    }

    addChild(child: Value) {
        child.parent = this;
        this.expr.push(child);
        this.id_map[child.id] = child;
        this.bind(child.name, child);
    }

    removeChild(child: Value){
        this.expr.splice(this.expr.indexOf(child), 1);
        delete this.name_map[child.name];
        delete this.id_map[child.name];
    }

    lookup(name: string, exclude?: Value) {
        /*
         Lookup a name in an environment.
         Return a list of found Values.
         Priority - lookup in self, then in children, then in parent.

         Exclude specifies Values not to search in (to prevent infinite recursion).
        */
        let uname = name.toUpperCase();

        if(undefined !== exclude && this.id === exclude.id) {
            return [];
        }
        if(uname in this.name_map){
            return [this.name_map[uname]];
        }
        let nameResolutions: Value[] = [];

        let thisNode = this;

        this.expr.forEach((child) => {
            if(exclude === undefined || child.id !== exclude.id){
                nameResolutions = nameResolutions.concat(child.lookup(uname, thisNode));
            }
        });

        if(this.parent !== null && (exclude === undefined || this.parent.id !== exclude.id)) {
            nameResolutions = nameResolutions.concat(this.parent.lookup(uname, this));
        }

        return nameResolutions;
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
        for(let i = length + 1; i < (length * 2) + 2; i++){
            let name = "Cell" + i;
            if(!(name in this.name_map)){
                return name;
            }
        }
        return ""
    }


}


// TODO
export class Table extends Group {
    // Can be used for single objects, as a map, or for more complex tables.
    // Distinction from above is multiple lists. It's more of a matrix.
    // So it's a list of groups. Neat.

    value: Group[] = [];

    type: string = "table";

}

export class Engine {
    root: Group;

    constructor() {
        this.root = new Group(this);
    }


    // TODO;
    rename(value: Value, name: string) {
        if(isValidName((name))){
            value.name = name;

        }
    }



}
import {castLiteral, detectType, formatValue, isValidName} from "../utils";
import {} from "../constants.ts"



export class Value {
    id: string;
    name: string;

    type: string;
    value: string | string[] | Value[] = "";

    depends_on: Value[] = [];
    used_by: Value[] = [];

    parent: Group | null = null;
    engine: Engine;

    errors: string[] = [];

    _parsed = null;
    _result = null;
    _is_stale = true;
    _value_type: string = "";   // One of FORMULA, BOOL, STR, NUM

    // Temporary shadow node used to make edits to before they're verified and commited.
    _shadow: Object | null = null;

    constructor(value: string, engine: Engine) {
        this.type = "value";
        this.engine = engine;
        this.id = util.generate_random_id();

        this.setValue(newValue);
    }

    addDependency(other: Value) {
        this.depends_on.push(other);
        other.used_by.push(this);
    }

    rename(newName: string) {
        let shadow = this.getShadow();
        let NAME_ERROR = "Variable names should start with a letter and can only contain letters, numbers, _ and -";
        if(newName == ""){
            shadow.name = newName;
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
        // TODO: Set shadow
        this.value = newValue;
        this._value_type = detectType(newValue);
        if(this._value_type == TYPE_FORMULA){
            this._parsed = parseFormula(this.value, this.engine);
        } else {
            this._parsed = null;
        }

        // todo - OTHER TYPES, ESP STRING
    }

    to_string() {
        return formatValue(this.value);
    }

    to_json() {

    }

    getShadow(){
        if(this._shadow == null){
            // Create it.
            this._shadow = {
                name: this.name,
                value: this.value
            }
            return this._shadow;
        }
        return this._shadow;
    }

    _doEvaluate(){
        let EVAL_ERR_PREFIX = "Evaluation error: "
        // Does the core of evaluate without any of the caching layers.
        // Can be overwritten.
        if(this.value == undefined || this.value == null){
            return undefined;
        }

        if(this._value_type == TYPE_FORMULA){
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
                return this.value;
            }
        }
        else if(this._value_type == TYPE_STRING) {
            return evaluateStr(this.value, this.engine);
        } else {
            // Numbers and booleans
            return castLiteral(this.value);
        }

    }

    // @ts-ignore - return type any.
    evaluate() {

        // If the cell is being modified, evaluate shadow instead.
        if(this._shadow != null){
            return this._shadow.evaluate()
        }

        if(this._is_stale){
            // Re-evaluate and set this._result;
            return this._doEvaluate();
        }

        // Return cached.
        return this._result;
    }

    markDirty(){
        if(!this._is_stale){
            this._is_stale = true;
            // Touch all of the cells that depend on this as well.
            this.used_by.forEach((val) => val.markDirty());
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

}

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

    constructor(engine: Engine) {
        super([], engine);
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
        return this.value;
    }

    destruct(){
        super.destruct();
        while(this.value.length > 0){
            // Pop elements from end of list
            this.value.pop().destruct();
        }
    }

    removeChild(child: Value){
        this.value.splice(this.value.indexOf(child), 1);
        // TODO: unbind cell
        // remove from all cells.
        // remove from id map and name map.
        delete this.name_map[child.name];
        delete this.id_map[child.name];
    }

}

export class Engine {
    root: Group;

    constructor() {
        this.root = new Group(this);
    }


    rename(value: Value, name: string) {
        let shadow = value.getShadow();
        if(name == "" || isValidName((name))){

            // @ts-ignore: prop name does exist.
            shadow.name = name;

        }
    }

    commit(value: Value) {
        // Commit the modifications in shadow.
    }
}
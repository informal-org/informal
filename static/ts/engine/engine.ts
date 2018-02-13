import {isValidName} from "../utils";


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

    setValue(newValue: string) {
        // TODO: parse and set dependencies.
        this.value = newValue;
    }

    to_string() {

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
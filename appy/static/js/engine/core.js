import { Obj, KeySignature, Param } from "./flex"
import { Stream } from "./Stream"
import { __aa_call } from "../utils"


// export function __add(a, b) { return a + b  }
// export function __sub(a, b) { return a - b  }

// String add[String a, String b]

function sig(return_type, name, params, guard=null, optional_index=1000, rest_params=false) {
    let paramObjs = params.map((p) => {
        new Param(p[0], p[1])
    })
    return new KeySignature(return_type, name, paramObjs, guard, optional_index, rest_params)
}


export const GLOBAL_ENV = new Obj();

GLOBAL_ENV.insert(sig("number", "__add", ["number", "a", "number", "b"]), 
(a, b) => a + b);

GLOBAL_ENV.insert(sig("string", "__add", ["number", "a", "string", "b"]), 
(a, b) => "" + a + b);

// TODO: This should be a recursive call?
GLOBAL_ENV.insert(sig("Stream", "__add", ["number", "a", "Stream", "b"]), 
(a, b) => b.map((x) => a + x));

GLOBAL_ENV.insert(sig("Stream", "__add", ["Stream", "a", "number", "b"]), 
(a, b) => a.map((x) => x + b));

// TODO?
// GLOBAL_ENV.insert(sig("Stream", "__add", ["Stream", "a", "string", "b"]), 
// (a, b) => a.map((x) => x + b));

GLOBAL_ENV.insert(sig("Stream", "__add", ["Stream", "a", "Stream", "b"]), 
(a, b) => a.binaryOp(((x, y) => x + y), b))

GLOBAL_ENV.insert(sig("string", "__add", ["string", "a", "string", "b"]), 
(a, b) => a + b);

GLOBAL_ENV.insert(sig("string", "__add", ["string", "a", "number", "b"]), 
(a, b) => a + b);

// TODO: String + obj -> to String
import { CellEnv } from "@appassembly/compiler/CellEnv.js";
import { defineNamespace, resolve } from "@appassembly/compiler/namespace.js"


const TREE_NESTED = {
    1: {
        id: 1,
        name: "a",
        depends_on: [2, 3],     // Extracted from parse tree after name resolution.
        
        body: [2, 3],
        params: []
    },
    2: {
        id: 2,
        name: "b",
        depends_on: [],
  
        body: [],
        params: []
    },
    3: {
        id: 3,
        name: "c",
        depends_on: [4],
  
        body: [4],
        params: []
    }, 
    4: {
      id: 4,
      name: "d",
      depends_on: [5, 6],
  
      body: [5, 6],
      params: []
    }, 
    5: {
      id: 5,
      name: "e",
      depends_on: [],
  
      body: [],
      params: []
    }, 
    6: {
      id: 6,
      name: "f",
      depends_on: [],
  
      body: [],
      params: []
    }
  }

//        a
//     b    c
//          d
//        e   f
test('scoped name resolution', () => {
    let env = new CellEnv();
    let root = env.create(TREE_NESTED, 1);

    defineNamespace(root)

    let a = env.getCell(1);
    let b = env.getCell(2);
    let c = env.getCell(3);
    let d = env.getCell(4);
    let e = env.getCell(5);
    let f = env.getCell(6);

    // Expected order. Doesn't care if e is before or after f.

    // Child can reference up the parent chain
    expect(resolve(f, "e")).toEqual(e);
    expect(resolve(f, "d")).toEqual(d);
    expect(resolve(f, "c")).toEqual(c);

    // Parent chain can't access nested child scope
    expect(resolve(c, "f")).toEqual(undefined);
    expect(resolve(a, "d")).toEqual(undefined);

    // Can access direct desendents
    expect(resolve(a, "b")).toEqual(b);  
    expect(resolve(a, "c")).toEqual(c);

});

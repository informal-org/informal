import { Cell } from '@appassembly/compiler/Cell.js';
import { CellEnv } from "@appassembly/compiler/CellEnv";


const ROOT_ID = 0;

// Valid basic tree
//        a
//     b    c
//          d
//        e   f
// Expected: e/f d c b a
export const TREE_BASIC = {
  0: {
    id: ROOT_ID,
    name: "root",
    depends_on: [], 

    body: [1, 2, 3, 4, 5, 6],
    params: []
  },
  1: {
      id: 1,
      name: "a",
      depends_on: [2, 3],     // Extracted from parse tree after name resolution.
      
      body: [],
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

      body: [],
      params: []
  }, 
  4: {
    id: 4,
    name: "d",
    depends_on: [5, 6],

    body: [],
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



test('mark dependency usage', () => {
    let env = new CellEnv();
    env.create(TREE_BASIC, 0);
    
    expect(Array.from(env.getUsedBy(2))).toEqual([1]);
})




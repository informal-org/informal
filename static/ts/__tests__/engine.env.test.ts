import {Engine, Value, Group} from '../engine/engine'

import {} from 'jest';
// import {test, expect, toEqual} from 'jest'

/* Environment tests */
// Test getting a variable in direct environment
test('find variable in direct environment', () => {
  let engine = new Engine();
  let env = engine.root;
  let c = new Value( "42", env, "a");
  expect(env.lookup("a")).toEqual([c]);  // Get correct env
  expect(env.lookup("b")).toEqual([]);


  expect(env.resolve("a")).toEqual(c);
  expect(env.resolve("b")).toEqual(null);

});

// Test getting in parent environment
test('find variable in parent environment', () => {
  let engine = new Engine();
  let parentEnv = engine.root;

  let childEnv = new Group(parentEnv);

  let c = new Value("42", parentEnv, "a");

  expect(childEnv.lookup("a")).toEqual([c]);
  expect(parentEnv.lookup("a")).toEqual([c]);

  expect(childEnv.resolve("a")).toEqual(c);
  expect(parentEnv.resolve("a")).toEqual(c);


});

// Testing getting in several layers deep
test('find variable in deep environment', () => {
  let engine = new Engine();
  let e1 = engine.root;

  let e2 = new Group(e1);
  let e3 = new Group(e2);
  let e4 = new Group(e3);
  let e5 = new Group(e4);
  let e6 = new Group(e5);

  // @ts-ignore:
  let c = new Value("42", e2, "a");

  expect(e5.resolve("a")).toEqual(c);  // Get correct env
  // expect(e1.resolve("a")).toEqual(null);  // Or namespace error in future
  expect(e1.resolve("a")).toEqual(c);  // In our system, you can search up the tree.
  expect(e6.resolve("a")).toEqual(c);

});

// Test variable found in multiple environments & proper one returned.
test('find variable in multiple scopes', () => {
  let engine = new Engine();
  let e1 = engine.root;
  let e2 = new Group(e1);
  let e3 = new Group(e2);
  let e4 = new Group(e3);
  let e5 = new Group(e4);

  // @ts-ignore:
  let c1 = new Value("42", e2, "a");
  // @ts-ignore:
  let c2 = new Value("32", e4, "a");


  expect(e1.lookup("a")).toEqual([c1]);
  // expect(e1.resolve("a")).toEqual(null);
  expect(e1.resolve("a")).toEqual(c1);

  expect(e2.lookup("a")).toEqual([c1]);
  expect(e2.resolve("a")).toEqual(c1);

  expect(e3.lookup("a")).toEqual([c2, c1]);
  expect(e3.resolve("a")).toEqual(c2);

  // Return the local variable rather than one in higher scope.
  expect(e4.lookup("a")).toEqual([c2]);
  expect(e4.resolve("a")).toEqual(c2);

  expect(e5.lookup("a")).toEqual([c2]);
  expect(e5.resolve("a")).toEqual(c2);

});
import {Engine} from '../engine'

import {} from 'jest';
// import {test, expect, toBe} from 'jest'

/* Environment tests */
// Test getting a variable in direct environment
test('find variable in direct environment', () => {
  let engine = new Engine()
  let env = engine.rootEnv;
  // @ts-ignore:
  let c = env.createCell("number", 42, "a")
  expect(env.findEnv("a")).toBe(env);  // Get correct env
  // @ts-ignore:
  expect(env.findEnv("a").findValue("a")).toBe(c); // get correct cell
  // @ts-ignore:
  expect(env.findEnv("a").lookup("a")).toBe(c); // Verify direct access
  expect(env.findValue("a")).toBe(c); // find + get
  // @ts-ignore:
  expect(env.findEnv("a").findValue("a").value).toBe(42);  // Verify value
});

// Test getting in parent environment
test('find variable in parent environment', () => {
  let engine = new Engine();
  let parentEnv = engine.rootEnv;
  let childEnv = parentEnv.createChildEnv();
  // @ts-ignore:
  let c = parentEnv.createCell("number", 42, "a");

  expect(childEnv.findEnv("a")).toBe(parentEnv);  // Get correct env
  expect(parentEnv.findEnv("a")).toBe(parentEnv);  // Get correct env

  // @ts-ignore:
  expect(childEnv.findEnv("a").findValue("a")).toBe(c); // get correct cell
  // @ts-ignore:
  expect(parentEnv.findEnv("a").findValue("a")).toBe(c); // get correct cell

  expect(childEnv.findValue("a")).toBe(c); // find + get

  // @ts-ignore:
  expect(childEnv.findEnv("a").findValue("a").value).toBe(42);  // Verify value

});

// Testing getting in several layers deep
test('find variable in deep environment', () => {
  let engine = new Engine()
  let e1 = engine.rootEnv;
  let e2 = e1.createChildEnv()
  let e3 = e2.createChildEnv()
  let e4 = e3.createChildEnv()
  let e5 = e4.createChildEnv()
  let e6 = e5.createChildEnv()
  // @ts-ignore:
  let c = e2.createCell("number", 42, "a");

  expect(e5.findEnv("a")).toBe(e2);  // Get correct env
  expect(e1.findEnv("a")).toBe(undefined);  // Or namespace error in future
  expect(e6.findValue("a")).toBe(c); // find + get

});

// Test variable not found.
test('find variable not found', () => {
  let engine = new Engine()
  let e = engine.rootEnv;
  // @ts-ignore:
  let c = e.createCell("number", 42, "a");

  expect(e.findEnv("b")).toBe(undefined);
  expect(e.findValue("b")).toBe(undefined);

  try {
    expect(e.lookup("b")).toThrow()
  } catch(err){
      expect(err.name).toEqual("EnvError")
      expect(err.env).toEqual(e)
  }


});

// Test variable found in multiple environments & proper one returned.
test('find variable in multiple scopes', () => {

  let engine = new Engine()
  let e1 = engine.rootEnv;
  let e2 = e1.createChildEnv()
  let e3 = e2.createChildEnv()
  let e4 = e3.createChildEnv()
  let e5 = e4.createChildEnv()
  let e6 = e5.createChildEnv()

  // @ts-ignore:
  let c1 = e2.createCell("number", 42, "a");
  // @ts-ignore:
  let c2 = e4.createCell("number", 32, "a");


  expect(e1.findEnv("a")).toBe(undefined);
  expect(e1.findValue("a")).toBe(undefined);

  expect(e2.findEnv("a")).toBe(e2);
  expect(e2.findValue("a")).toBe(c1);

  expect(e3.findEnv("a")).toBe(e2);
  expect(e3.findValue("a")).toBe(c1);

  // Return the local variable rather than one in higher scope.
  expect(e4.findEnv("a")).toBe(e4);
  expect(e4.findValue("a")).toBe(c2);

  expect(e5.findEnv("a")).toBe(e4);
  expect(e5.findValue("a")).toBe(c2);


});
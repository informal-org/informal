import {Engine, Value} from '../engine/engine'
import {} from 'jest';
import { getEvalOrder } from '../engine/evaluation';

// Test variable not found.
test('dependency order maintained', () => {
    let engine = new Engine()
    let env = engine.root;

    let a = new Value("A", env);
    let b = new Value("B", env);
    let c = new Value("C", env);
    let d = new Value("D", env);
    let e = new Value("E", env);
    let f = new Value("F", env);

    // #       a
    // #    b    c
    // #         d
    // #       e   f

    a.addDependency(b);
    a.addDependency(c);
    c.addDependency(d);
    d.addDependency(e);
    d.addDependency(f);

    let cells = [a, b, c, d, e, f];
    let evalOrder = getEvalOrder(cells);
    // Expect a return value
    expect(evalOrder).toBeDefined();
    // Expect everything to be present
    cells.forEach((cell) => {
        expect(evalOrder).toContain(cell);
    })
    // Expect maintained order.
    // Doesn't care if e is before or after f.
    expect(evalOrder.indexOf(e)).toBeLessThan(evalOrder.indexOf(d));
    expect(evalOrder.indexOf(f)).toBeLessThan(evalOrder.indexOf(d));
    expect(evalOrder.indexOf(d)).toBeLessThan(evalOrder.indexOf(c));
    expect(evalOrder.indexOf(c)).toBeLessThan(evalOrder.indexOf(a));
    expect(evalOrder.indexOf(b)).toBeLessThan(evalOrder.indexOf(a));
    expect(evalOrder.indexOf(a)).toEqual(evalOrder.length - 1); // A should be evaluated last

  });

  test('throws an error on cycles', () => {
    let engine = new Engine();
    let env = engine.root;


    let a = new Value("A", env);
    let b = new Value("B", env);
    let c = new Value("C", env);
    let d = new Value("D", env);
    let e = new Value("E", env);
    let f = new Value("F", env);

    // #       a
    // #    b    c
    // #         d
    // #       e   f
    //             d

    a.addDependency(b);
    a.addDependency(c);
    c.addDependency(d);
    d.addDependency(e);
    d.addDependency(f);
    f.addDependency(d);

    let cells = [a, b, c, d, e, f];
    // Expect a return value
    try {
        expect(getEvalOrder(cells)).toThrow()
    } catch(err){
        expect(err.name).toEqual("ValueError")
        expect(err).toHaveProperty("values");

        expect(err.values).toContainEqual(a);
        expect(err.values).toContainEqual(c);
        expect(err.values).toContainEqual(d);
        expect(err.values).toContainEqual(f);
        expect(err.values.length).toEqual(4);
    }
  });
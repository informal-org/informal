import {Engine} from '../engine'
import {} from 'jest';
import { getEvalOrder } from '../evaluation';

// Test variable not found.
test('dependency order maintained', () => {
    let engine = new Engine()
    let env = engine.rootEnv;

    let a = env.createCell("number", "A");
    let b = env.createCell("number", "B");
    let c = env.createCell("number", "C");
    let d = env.createCell("number", "D");
    let e = env.createCell("number", "E");
    let f = env.createCell("number", "F");

    // #       a
    // #    b    c
    // #         d
    // #       e   f

    a.addDependency(b)
    a.addDependency(c)
    c.addDependency(d)
    d.addDependency(e)
    d.addDependency(f)

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
    let engine = new Engine()
    let env = engine.rootEnv;


    let a = env.createCell("number", "A");
    let b = env.createCell("number", "B");
    let c = env.createCell("number", "C");
    let d = env.createCell("number", "D");
    let e = env.createCell("number", "E");
    let f = env.createCell("number", "F");

    // #       a
    // #    b    c
    // #         d
    // #       e   f
    //             d

    a.addDependency(b)
    a.addDependency(c)
    c.addDependency(d)
    d.addDependency(e)
    d.addDependency(f)
    f.addDependency(d)

    let cells = [a, b, c, d, e, f];
    // Expect a return value
    try {
        expect(getEvalOrder(cells)).toThrow()
    } catch(err){
        expect(err.name).toEqual("CellError")
        expect(err).toHaveProperty("cells");

        expect(err.cells).toContainEqual(a);
        expect(err.cells).toContainEqual(c);
        expect(err.cells).toContainEqual(d);
        expect(err.cells).toContainEqual(f);
        expect(err.cells.length).toEqual(4);
    }
  });
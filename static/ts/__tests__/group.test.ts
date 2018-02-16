import { Engine, Value, Group } from '../engine/engine';
import {} from 'jest';


test('test defining names', () => {
    // Case insensitive
    let engine = new Engine();

    console.log("Root: " + engine.root.id);
    // TODO: Create cell methods.
    let v = new Value("val", engine.root, "hello");
    console.log("Value: " + v.id);

    expect(engine.root.lookup("hello")).toEqual([v]);

    // Case insensitive
    expect(engine.root.lookup("HeLlO")).toEqual([v]);

    expect(engine.root.lookup("not_found")).toEqual([]);

});
import { Engine, Value, Group } from '../engine/engine';
import {} from 'jest';


test('test defining names', () => {
    // Case insensitive
    let engine = new Engine();

    console.log("Root: " + engine.root.id);
    // TODO: Create cell methods.
    let v = new Value("val", engine);
    console.log("Value: " + v.id);
    v.rename("hello");
    engine.root.addChild(v);

    expect(engine.root.lookup("hello")).toEqual([v]);

    // Case insensitive
    expect(engine.root.lookup("HeLlO")).toEqual([v]);

    expect(engine.root.lookup("not_found")).toEqual([]);

});
import { Obj } from "@informal/core/bootstrap.js"

test('Test obj unification', () => {
    let obj = new Obj();
    let x = obj.symbolFor("x");
    obj = obj.unify(x, 5)
    let y = obj.symbolFor("y")
    obj = obj.unify(y, x)

    expect(obj.value(x)).toEqual(5)
    expect(obj.value(y)).toEqual(5)
});

test('Test function selection', () => {
    let obj = new Obj();
    let foo = obj.symbolFor("foo");
    obj = obj.set(foo, "Foo")

    expect(obj.select(foo)).toEqual(5)
    expect(obj.value(y)).toEqual(5)
});


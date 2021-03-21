import { AbstractForm } from "@informal/core/bootstrap.js"

test('Test obj unification', () => {
    let obj = new AbstractForm();
    let x = obj.symbolFor("x");
    obj = obj.unify(x, 5)
    let y = obj.symbolFor("y")
    obj = obj.unify(y, x)

    expect(obj.value(x)).toEqual(5)
    expect(obj.value(y)).toEqual(5)
});

test('Test selection', () => {
    let obj = new AbstractForm();
    let foo = obj.symbolFor("foo");
    obj = obj.set(foo, "Foo")

    expect(obj.select(foo)).toEqual(5)
    expect(obj.value(y)).toEqual(5)
});

test('Test add function', () => {
    // Name -> signatures
    // Signature -> body
    // return -> type, param -> type
    // add:
    //      (a Type, b Type) Type : fn()

    let addSig = new AbstractForm();

    let Integer = addSig.symbolFor("Integer")

    let symbolA = addSig.symbolFor("a")
    let symbolB = addSig.symbolFor("b")

    let symbolReturn = addSig.symbolFor("return")

    // Return type. Always the first entry.
    addSig = addSig.set(symbolReturn, Integer)

    addSig = addSig.set(symbolA, Integer)
    addSig = addSig.set(symbolB, Integer)

    // Fn = signature -> body
    let fn = new AbstractForm();
    fn = fn.set(addSig, (a, b) => {
        console.log("Add called with " + a + " " + b)
        return a + b
    })

    let result = fn.call(true, 2, 3);

    expect(result).toEqual(5)
});


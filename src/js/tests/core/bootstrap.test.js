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

    let paramA = new Form()
    paramA = paramA.set(paramA.symbolFor("a"), Integer)

    let paramB = new Form()
    paramB = paramB.set(paramB.symbolFor("b"), Integer)

    let params = new CompoundForm([paramA, paramB]);

    // [a: Integer, b: Integer] -> Integer
    addSig = addSig.set(params, Integer)


    // Fn = signature -> body
    let fn = new AbstractForm();
    fn = fn.set(addSig, (a, b) => {
        console.log("Add called with " + a + " " + b)
        return a + b
    })

    let result = fn.call(true, 2, 3);

    expect(result).toEqual(5)
});


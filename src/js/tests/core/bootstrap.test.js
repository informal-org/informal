import { AbstractForm, Form, CompoundForm } from "@informal/core/bootstrap.js"

test('Test obj unification', () => {
    let obj = new Form();
    let x = obj.symbolFor("x");
    obj = obj.unify(x, 5)
    let y = obj.symbolFor("y")
    obj = obj.unify(y, x)

    expect(obj.resolve(x)).toEqual(5)
    expect(obj.resolve(y)).toEqual(5)
});

test('Test selection', () => {
    let obj = new AbstractForm();
    let foo = obj.symbolFor("foo");
    obj = obj.set(foo, "Foo")

    expect(obj.select(foo)).toEqual(5)
    expect(obj.get(y)).toEqual(5)
});

test('Test untyped function', () => {
    // Name -> signatures
    // Signature -> body
    // return -> type, param -> type
    // add:
    //      (a, b) : fn()

    let addSig = new CompoundForm([Symbol.for("a"), Symbol.for("b")]);

    // Fn = signature -> body
    let fn = new Form();
    fn = fn.set(addSig, (a, b) => {
        console.log("Add called with " + a + " " + b)
        return a + b
    })

    let params = new CompoundForm([2, 3]);
    let result = fn.apply(params);

    expect(result).toEqual(5)
});

// test('Test typed function', () => {
//     // Name -> signatures
//     // Signature -> body
//     // return -> type, param -> type
//     // add:
//     //      (a Type, b Type) Type : fn()

//     let addSig = new Form();
//     let Integer = addSig.symbolFor("Integer")

//     let paramA = new Form()
//     paramA = paramA.set(paramA.symbolFor("a"), Integer)

//     let paramB = new Form()
//     paramB = paramB.set(paramB.symbolFor("b"), Integer)

//     let params = new CompoundForm([paramA, paramB]);

//     // [a: Integer, b: Integer] -> Integer
//     addSig = addSig.set(params, Integer)


//     // Fn = signature -> body
//     let fn = new Form();
//     fn = fn.set(addSig, (a, b) => {
//         console.log("Add called with " + a + " " + b)
//         return a + b
//     })

//     let callA = new Form();
//     callA = callA.set()
//     let result = fn.apply(2, 3);

//     expect(result).toEqual(5)
// });

// Test parameter interdependence, a: Integer, b: a
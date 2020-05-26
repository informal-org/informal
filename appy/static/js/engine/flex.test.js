import { Obj } from "./flex"

test('Object with obj keys', () => {
    // When cells don't depend on each other, their order remains the same
    let obj = new Obj();
    let a = {"a": 1, "b": 2}
    obj.insert(a, "A_VALUE")

    expect(obj.lookup(a)).toEqual("A_VALUE")
    expect(obj.getKey(a._aakey)).toEqual(a)

    console.log(a);
    console.log(obj._data)
});

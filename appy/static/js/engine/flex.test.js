import { Obj } from "./flex"

test('Object with obj keys', () => {
    // When cells don't depend on each other, their order remains the same
    let obj = new Obj();
    let a = {"a": 1, "b": 2}
    obj.insert(a, "A_VALUE")

    expect(obj.lookup(a)).toEqual("A_VALUE")
    expect(obj.getKey(a.$aa_key)).toEqual(a)
});



test('fibo repr', () => {
    let fibo = new Obj();
    fibo.insert(0, 0)
    fibo.insert(1, 1)

    let rec = new Obj((n) => {
        return fibo.call(n - 1) + fibo.call(n - 2)
    })
    let n = new Obj(["n"]);
    fibo.insert(n, rec);
    
    // console.log(fibo._values)
    // console.log(fibo._keys)

    expect(fibo.call(1)).toEqual(1)
    expect(fibo.call(2)).toEqual(1)
    expect(fibo.call(7)).toEqual(13)
});

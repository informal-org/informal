import { Obj, Stream } from "./flex"

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



test('stream representation', () => {
    let stream = Stream.range(0, 5);
    expect(Array.from(stream.iter())).toEqual([0, 1, 2, 3, 4])

    // Step size of 2
    stream = Stream.range(0, 5, 2);
    expect(Array.from(stream.iter())).toEqual([0, 2, 4])

    stream = Stream.range(0, 5);
    stream = stream.map((x) => x * 3)
    expect(Array.from(stream.iter())).toEqual([0, 3, 6, 9, 12])

    // Filter to even numbers
    stream = Stream.range(0, 10);
    stream = stream.filter((x) => x % 2 == 0)
    expect(Array.from(stream.iter())).toEqual([0, 2, 4, 6, 8])

    // Square even numbers
    stream = Stream.range(0, 10);
    stream = stream.filter((x) => x % 2 == 0)
    stream = stream.map((x) => x * x)
    expect(Array.from(stream.iter())).toEqual([0, 4, 16, 36, 64])
    

    let a = Stream.range(0, 5);
    let b = Stream.range(5, 10);

    let result = a.binaryOp((elem1, elem2) => {
        return elem1 + elem2
    }, b)

    console.log("Combined is: ")
    console.log(Array.from(result.iter()));

    // 0 1 2 3 4
    // 5 6 7 8 9
    expect(Array.from(result.iter())).toEqual([5, 7, 9, 11, 13])

})
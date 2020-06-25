import { Obj, KeySignature } from "./flex"
import { Stream } from "./Stream"

test('Object with obj keys', () => {
    // When cells don't depend on each other, their order remains the same
    let obj = new Obj();
    let a = {"a": 1, "b": 2}
    obj.insert(a, "A_VALUE")

    expect(obj.lookup(a)).toEqual("A_VALUE")
    expect(obj.getKey(a.$aa_key)).toEqual(a)

    //  Do the same thing, but using constructor init
    obj = new Obj([[a, "A_VALUE"]])
    expect(obj.lookup(a)).toEqual("A_VALUE")
    expect(obj.getKey(a.$aa_key)).toEqual(a)
});


test('add repr', () => {
    let add = new Obj();    
    let addFn = (a, b) => {
        return a + b
    }

    let sig = new KeySignature("", null, [
        new KeySignature("a"),
        new KeySignature("b"),
    ])
    add.insert(sig, addFn);
    
    // console.log(fibo._values)
    // console.log(fibo._keys)

    expect(add.call(1, 1)).toEqual(2)
    expect(add.call(2, 4)).toEqual(6)
    expect(add.call(7, 5)).toEqual(12)
});





test('fibo repr', () => {
    let fibo = new Obj();
    fibo.insert(0, 0)
    fibo.insert(1, 1)
    
    let rec = (n) => {
        return fibo.call(n - 1) + fibo.call(n - 2)
    }

    let sig = new KeySignature("", null, [
        new KeySignature("n")
    ])
    fibo.insert(sig, rec);
    
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

    // 0 1 2 3 4
    // 5 6 7 8 9
    expect(Array.from(result.iter())).toEqual([5, 7, 9, 11, 13])

    // Lazy concat of two streams
    a = Stream.range(0, 5);
    b = Stream.range(5, 10);
    result = a.concat(b)

    expect(Array.from(result.iter())).toEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])

})

test('stream indexing', () => {
    let stream = Stream.range(0, 5);
    expect(stream.get(0)).toEqual(0)
    expect(stream.get(4)).toEqual(4)
    // Should just re-use the existing cached entry
    expect(stream.get(2)).toEqual(2)
})

test('stream fold', () => {
    let stream = Stream.range(0, 10);
    // fn, (init)
    expect(stream.reduce((acc, x) => acc + x)).toEqual(45)
})
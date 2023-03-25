const { readFileSync } = require('fs');

const init = async (file) => {
    const buffer = readFileSync(file);
    const compiled = await WebAssembly.compile(buffer);
    const instance = await WebAssembly.instantiate(compiled, {
        env: {}, 
    });
    console.log("Instance: ", instance.exports);
    return instance.exports;
}

beforeEach(async () => {
    wamin = await init('../Sources/Minformal/wamin.wasm');
});


test('adds 1 + 2 to equal 3', () => {
    expect(wamin.add(1, 2)).toBe(3);
    // expect(sum(1, 2)).toBe(3);
});
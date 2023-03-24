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
    wasm_win = await init('../Sources/Minformal/win.wasm');
});


test('adds 1 + 2 to equal 3', () => {
    expect(wasm_win.add(1, 2)).toBe(3);
    // expect(sum(1, 2)).toBe(3);
});
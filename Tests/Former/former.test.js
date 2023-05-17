const { readFileSync } = require('fs');
const { spawnSync } = require( 'child_process' );

const load = async (file) => {
    const buffer = readFileSync(file);
    const compiled = await WebAssembly.compile(buffer);
    const instance = await WebAssembly.instantiate(compiled, {
        env: {}, 
    });
    console.log("Instance: ", instance.exports);
    return instance.exports;
}

const compile = async (code) => {
    // Compile an Informal expression
    let compileOut = spawnSync('just', ['compile', `"${code}"`, '../../Tests/Former/build/test'], {cwd: "../Sources/Former/"} );
}

// beforeEach(async () => {
//     // wamin = await init('../Sources/Former/zig-out/bin/Former');
// });

// function writeI32(memory, offset, contents) {
//     const buffer = new Int32Array(memory.buffer, offset, 1);
//     buffer[0] = contents;
//     return buffer.byteOffset;
// }

// function writeBytes(memory, offset, contents) {
//     const buffer = new Uint8Array(memory.buffer, offset, contents.length)
//     buffer.set(contents, offset);
// }

// function writeStringToMemory(string, memory, offset) {
//     const bytes = new TextEncoder().encode(string);
//     // [length, ...bytes]
//     offset = writeI32(memory, offset, bytes.length);
//     offset = writeBytes(memory, offset, bytes);
//     // const length = utf8Str.length;
//     // const ptr = buffer;
//     // stringToUTF8(string, ptr, length + 1);
//     // return ptr;
// }


async function evaluate(expression) {
    compile(expression)
    const wasm_exports = await load('Former/build/test.wasm');
    return wasm_exports._start();
}


test('Basic numeric expressions', async () => {
    // Ensure mathematical operator precedence.
    expect(await evaluate("1 + 1")).toBe(2);
    expect(await evaluate("1 + 2 * 4")).toBe(9);
    expect(await evaluate("1 * 2 + 3")).toBe(5);
});

test('Parentheses', async () => {
    // Parentheses take precedence.
    expect(await evaluate("(1 + 2) * 4")).toBe(12);
    expect(await evaluate("4 * (2 + 3) + 7")).toBe(27);
});

test('Comments', async () => {
    expect(await evaluate("// Hello")).toBe(12);
    expect(await evaluate("4 * (2 + 3) + 7")).toBe(27);
});

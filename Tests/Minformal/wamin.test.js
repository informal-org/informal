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

function writeI32(memory, offset, contents) {
    const buffer = new Int32Array(memory.buffer, offset, 1);
    buffer[0] = contents;
    return buffer.byteOffset;
}

function writeBytes(memory, offset, contents) {
    const buffer = new Uint8Array(memory.buffer, offset, contents.length)
    buffer.set(contents, offset);
}

function writeStringToMemory(string, memory, offset) {
    const bytes = new TextEncoder().encode(string);
    // [length, ...bytes]
    offset = writeI32(memory, offset, bytes.length);
    offset = writeBytes(memory, offset, bytes);
    // const length = utf8Str.length;
    // const ptr = buffer;
    // stringToUTF8(string, ptr, length + 1);
    // return ptr;
}


test('Runs lexer', () => {
    let mem = wamin.memory;
    // writeStringToMemory("1, 2, 3", mem, 0);
    const lex = wamin.init(0);

    // expect(wamin.add(1, 2)).toBe(3);
    // expect(sum(1, 2)).toBe(3);
});
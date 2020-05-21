import { v4 as uuidv4 } from 'uuid';

// A port of the python shortuuid library to be output compatible

// The alphabet from the python version
const SHORTUUID_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const SHORT_PAD_LEN = 22;   // Pre-computed expected shortuuid length

function encodeID(number) {
    // Parameter - Number - BigInt
    var output = "";
    var alpha_len = BigInt(SHORTUUID_ALPHABET.length)
    
    while (number > 0) {
        var div = number / alpha_len;   // Fraction will be truncated
        var base_index = number % alpha_len;
        number = div;
        output += SHORTUUID_ALPHABET[base_index.valueOf()];
    }

    // Add padding to account for any fractional truncation
    for(var i = 0; i < SHORT_PAD_LEN - output.length; i++) {
        output += SHORTUUID_ALPHABET[0];
    }
    return output
}

export function genID() {
    var buffer = new Array();
    uuidv4(null, buffer, 0); 
    var uuid_hex = "0x";
    buffer.forEach((b) => {
        uuid_hex += b.toString(16);
    });
    var number = BigInt(uuid_hex);
    return encodeID(number);
}
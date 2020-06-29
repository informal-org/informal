/** 
 * LEB encoding. Loosely based on
 * https://github.com/gimli-rs/leb128
 * 
 * This LEB 128 encoding module is licensed under the MIT license.
 * http://opensource.org/licenses/MIT
 */

const CONTINUATION_BIT: u8 = 1 << 7;
const SIGN_BIT: u8 = 1 << 6;

const MAX_BYTE = 255;


#[inline]
fn low_bits_of_byte(byte: u8) -> u8 {
    // Byte & 0x7F = byte & 0111 1111
    byte & !CONTINUATION_BIT
}

#[inline]
fn low_bits_of_u64(val: u64) -> u8 {
    let byte = val & (255 as u64);
    low_bits_of_byte(byte as u8)
}

pub fn writeByte(byte: u8) {
    
}


pub fn writeUnsigned(mut n: u64) {
    let mut buffer;
    loop {
        let mut byte = low_bits_of_u64(n);
        n >>= 7;
        if(val != 0) {
            // More bytes to come.
            byte |= CONTINUATION_BIT;
            writeByte(byte);
        }

    }
}

pub fn writeSigned(n: u64) {
    // TODO
}


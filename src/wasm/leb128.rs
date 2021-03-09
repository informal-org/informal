/** 
 * LEB encoding. Loosely based on
 * https://github.com/gimli-rs/leb128
 * 
 * This LEB 128 encoding module is licensed under the MIT license.
 * http://opensource.org/licenses/MIT
 */

const CONTINUATION_BIT: u8 = 1 << 7;
const SIGN_BIT: u8 = 1 << 6;

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


pub fn encode_unsigned(mut n: u64) -> Vec<u8> {
    let mut buffer: Vec<u8> = vec![];
    loop {
        let mut byte = low_bits_of_u64(n);
        n >>= 7;
        if n != 0 {
            // More bytes to come.
            byte |= CONTINUATION_BIT;
        }
        buffer.push(byte);
        
        if n == 0 {
            return buffer
        }
    }
    
}

pub fn encode_signed(n: u64) {
    // TODO
}


#[cfg(test)]
mod tests {
    use super::*;
    // extern crate test;

    #[test]
    fn test_encode_unsigned() {
        let result = encode_unsigned(7);
        let expected = vec![
            0x07
        ];

        assert_eq!(expected, result);
    }
}
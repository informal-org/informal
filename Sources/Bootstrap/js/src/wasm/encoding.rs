use crate::leb128::*;

pub fn encode_string(s: String) -> Vec<u8> {
    let mut buffer: Vec<u8> = vec![];
    let len: u64 = s.len() as u64;
    buffer.append(&mut encode_unsigned(len));

    let mut bytes: Vec<u8> = s.bytes().collect();
    buffer.append(&mut bytes);

    return buffer;
}

pub fn encode_vector(mut v: Vec<u8>) -> Vec<u8> {
    let mut buffer: Vec<u8> = vec![];
    let len: u64 = v.len() as u64;
    buffer.append(&mut encode_unsigned(len));
    buffer.append(&mut v);
    return buffer;
}

pub fn encode_nested_vector(mut v: Vec<Vec<u8>>) -> Vec<u8> {
    let mut buffer: Vec<u8> = vec![];
    let len: u64 = v.len() as u64;
    buffer.append(&mut encode_unsigned(len));
    // Append sub-vectors
    for mut sv in v {
        buffer.append(&mut sv);
    }
    return buffer;
}


pub fn encode_section(section: u8, mut data: Vec<u8>) -> Vec<u8> {
    let mut buffer: Vec<u8> = vec![section];
    buffer.append(&mut encode_vector(data));
    return buffer;
}

#[cfg(test)]
mod tests {
    use super::*;
    // extern crate test;


    #[test]
    fn test_encode_vector() {
        let test_data = vec![0x01, 0x60, 0x02, 0x7d, 0x7d, 0x01, 0x7d];
        let result = encode_vector(test_data);
        let expected = vec![
            0x07, 0x01, 0x60, 0x02, 0x7d, 0x7d, 0x01, 0x7d
        ];

        assert_eq!(expected, result);
    }
}
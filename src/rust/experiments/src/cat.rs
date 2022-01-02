/* 
CAT - Content Addressed Table - An efficient indexed data structure for sorted, associative data.
Designed for strings and numbers, but applicable broadly.

Each layer behaves like a radix tree. The radix array is sized in powers of two and it indicates how many of the MSB bits we index by.
The radix array implements dynamic re-balancing based on a load-factor, doubling and thus splitting it's child-layers.
[A, B, C, D, ..., Z] -> [AA, AB, AC, ... ZZ] (but at the bit/byte level).

To balance radix tree depth, it's combined with a prefix-trie style structure. 
Each edge value contains the largest string prefix and a pointer to a prefix-tree. 
"H" -> [->"ello", ->[@0, @1, @2, @3, @4]]
The array index @0 points to the next layer of the radix tree for any that doesn't match the prefix. 
@1 points to the layer with one shared character prefix.
@4 points to the layer with the full prefix matching. 
Thus, we get value out of each comparison. This trie-structure is capped at 8, even though the prefix compared can be much larger.

Radix nodes consume a fixed size chunk of bytes per layer. The prefix edges consume variable sized prefix matches and any sub-elements.
*/

#[derive(Debug)]
struct CatRadixNode {
    edges: Vec<Box<Option<CatPrefixEdge>>>
}

#[derive(Debug)]
struct CatPrefixEdge {
    // Shared common prefix string.
    prefix: Box<String>,
    // Array of length 0-8 elements.
    nodes: Vec<Box<Option<CatRadixNode>>>
}

fn here_kitty_kitty() -> CatRadixNode {
    // Dangle a string in front of the cat and initialize it.
    // Make a tiny little tree for it to climb.
    const size: usize = 8;
    let mut edges: Vec<Box<Option<CatPrefixEdge>>> = Vec::with_capacity(size);

    for i in 0..size {
        edges.push(Box::new(Option::None));
    }

    return CatRadixNode {
        edges: edges
    }

}

fn good_kitten_heres_a_treat(root: &mut &CatRadixNode, elem: u64) {
    // Good kitten!! Here's a treat. 
    // Put a ball in the tree.

    
}

fn wheres_da_ball_kitten(root: &mut &CatRadixNode, elem: u64) {
    // Where is da ball, kitten!? 
    // Go look for the ball in the tree.

}


mod tests {
    use super::*;
    extern crate test;

    use test::Bencher;
    pub const BENCH_SIZE: u64 = 10_000;

    use rand;

    fn gensort(length: u64) {

    }

    #[bench]
    fn bench_feast(b: &mut Bencher) {
        b.iter(|| {
            // let mut arr = gensort(BENCH_SIZE);
            // arr.sort();
        });
    }

    #[bench]
    fn bench_detective(b: &mut Bencher) {
        b.iter(|| {
            // let mut arr = gensort(BENCH_SIZE);
            // arr.sort();
        });
    }

    
    #[test]
    fn test_kitten_protocol() {
        let kitten = here_kitty_kitty();
        println!("{:?}", kitten);
        // assert_eq!(expected, result);
    }

}


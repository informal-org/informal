// Experimenting with a graph based sorting algorithm
use std::cmp::Ordering;
use std::vec::Vec;

// Vec<Box<PartialOrd>> 
fn graph_sort(list: &[u64]) -> Vec<u64> {
    // println!("Sort {:?}", list);
    // Each array is pivot, followed by elements less than that pivot.
    let mut pivots: Vec<Vec<u64>> = Vec::new();
    for elem in list.iter() {
        let mut found = false;

        // TODO: A variation of this using the last mut could be better in real-world datasets, where the
        // end of the list is more likely to be unsorted.
        // TODO: Binary search for insert
        for pivotArr in pivots.iter_mut() {
            let pivot: u64 = *pivotArr.first().unwrap();

            // Optimization: On second sort, flip this.
            if *elem <= pivot {
                pivotArr.push(*elem);
                found = true;
                break;
            }
        }
        
        // The new element is greater than all pivots currently in sorted arr
        if !found {
            let mut subVec: Vec<u64> = Vec::new();
            subVec.push(*elem);
            pivots.push(subVec)
        }
    }

    // Read the resulting array out in sorted order.
    let mut sorted: Vec<u64> = Vec::new();
    // println!("Pivots {:?}", pivots);
    for arr in pivots.iter() {
        if arr.len() > 1 {
            
            // All elements following the pivot are less than pivot. Sub-sort it. 
            // Optimization: Using insertion sort if this sub-array is small.
            sorted.append(&mut graph_sort(&arr[1..]));
        }
        sorted.push(arr[0])
    }
    return sorted;
}

mod tests {
    use super::*;
    extern crate test;

    use test::Bencher;
    pub const BENCH_SIZE: u64 = 1000;

    use rand;

    fn gensort(length: u64) -> Vec<u64> {
        let mut arr: Vec<u64> = Vec::with_capacity(length as usize);
        for _ in 0..length {
            let i: u64 = rand::random();
            // arr.push(i % 100000);
            arr.push(i);
        }
        return arr
    }

    #[bench]
    fn bench_std_sort(b: &mut Bencher) {
        b.iter(|| {
            let mut arr = gensort(BENCH_SIZE);
            arr.sort();
        });
    }

    #[bench]
    fn bench_graph_sort(b: &mut Bencher) {
        // println!("Testing gensort");
        b.iter(|| {
            let mut arr = gensort(BENCH_SIZE);
            let result = graph_sort(&arr[..]);
        });
        // println!("{:?}", result);
    }

}

/* 
Preliminary results
test sort::tests::bench_graph_sort ... bench:   1,661,755 ns/iter (+/- 237,543)
test sort::tests::bench_std_sort   ... bench:     346,789 ns/iter (+/- 3,882)
*/
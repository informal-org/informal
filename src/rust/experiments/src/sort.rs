// Experimenting with a graph based sorting algorithm
use std::cmp::Ordering;
use std::vec::Vec;
use sorts;

fn binary_insert(list: &mut Vec<u64>, elem: u64) {
    if list.len() <= 1 {
        list.push(elem)
    }
    // else if list.len() < 16 {
    //     // Linear search and insert
    //     let mut insertIndex = -1;
    //     for i in 1..list.len() {
    //         if list[i] > elem {
    //             insertIndex = i;
    //             break;
    //         }
    //     }
    // }
    else if list.len() < 64 {
        let idx = list[1..].binary_search(&elem).unwrap_or_else(|x| x);
        list.insert(idx + 1, elem);
    } else {
        list.push(elem);
    }
}

fn find_pivot_linear(pivots: &Vec<Vec<u64>>, elem: u64) -> usize {
    for (index, pivotArr) in pivots.iter().enumerate() {
        let pivot: u64 = *pivotArr.first().unwrap();
        if elem <= pivot {
            return index
        }
    }
    return pivots.len()
}

fn find_pivot_binary(pivots: &Vec<Vec<u64>>, elem: u64) -> usize {
    let idx = pivots.binary_search_by_key(&elem, |pivotArr| *pivotArr.first().unwrap()).unwrap_or_else(|x| x);
    return idx;
}

// Vec<Box<PartialOrd>> 
fn graph_sort(list: &[u64]) -> Vec<u64> {
    // println!("Sort {:?}", list);
    // Each array is pivot, followed by elements less than that pivot.
    let mut pivots: Vec<Vec<u64>> = Vec::with_capacity(list.len() / 32);
    for elem in list.iter() {
        let mut found = false;

        // TODO: A variation of this using the last mut could be better in real-world datasets, where the
        // end of the list is more likely to be unsorted.
        // TODO: Binary search for insert
        // let pivotIdx = find_pivot_linear(&pivots, *elem);
        let pivotIdx = find_pivot_binary(&pivots, *elem);
        // println!("Pivot idx {:?} of {:?}", pivotIdx, pivots.len());
        if pivotIdx == pivots.len() {
            // println!("Inserting new arr");
            let mut subVec: Vec<u64> = Vec::new();
            subVec.push(*elem);
            pivots.push(subVec)
            
        } else {
            // println!("Binary inserting into arr");
            binary_insert(&mut pivots[pivotIdx], *elem);
        }
    }

    // Read the resulting array out in sorted order.
    let mut sorted: Vec<u64> = Vec::with_capacity(list.len());
    // println!("Pivots {:?}", pivots);
    for arr in pivots.iter() {
        if arr.len() >= 64 {
            // All elements following the pivot are less than pivot. Sub-sort it. 
            // Optimization: Using insertion sort if this sub-array is small.
            sorted.append(&mut graph_sort(&arr[1..]));
        } else {
            // The list should already be sorted
            sorted.extend_from_slice(&arr[1..]);
        }
        sorted.push(arr[0])
    }
    return sorted;
}

mod tests {
    use super::*;
    extern crate test;

    use test::Bencher;
    pub const BENCH_SIZE: u64 = 10_000;

    use rand;

    fn gensort(length: u64) -> Vec<u64> {
        let mut arr: Vec<u64> = Vec::with_capacity(length as usize);
        for _ in 0..length {
            let i: u64 = rand::random();
            // arr.push(i % 1000);
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
            // println!("Sorted? {:?}", result);
        });
        
    }

}

/* 
Preliminary results. N = 10k
test sort::tests::bench_graph_sort ... bench:   1,661,755 ns/iter (+/- 237,543)
test sort::tests::bench_std_sort   ... bench:     346,789 ns/iter (+/- 3,882)

Added insertion sort
test sort::tests::bench_graph_sort ... bench:   1,812,005 ns/iter (+/- 56,753)
test sort::tests::bench_std_sort   ... bench:     347,709 ns/iter (+/- 11,511)

Binary search with insert
test sort::tests::bench_graph_sort ... bench:   1,099,272 ns/iter (+/- 68,847)
test sort::tests::bench_std_sort   ... bench:     347,421 ns/iter (+/- 4,211)

Changing linear pivot probing to binary search
test sort::tests::bench_graph_sort ... bench:   1,084,186 ns/iter (+/- 29,216)
test sort::tests::bench_std_sort   ... bench:     346,109 ns/iter (+/- 1,677)

Same with N=100k
test sort::tests::bench_graph_sort ... bench:  12,171,195 ns/iter (+/- 492,659)
test sort::tests::bench_std_sort   ... bench:   4,188,829 ns/iter (+/- 67,575)

It's an nlog(n) sort with a constant factor slowdown of 3 vs timsort.
I suspect all of the sub-allocations for the sub-arrays are causing most of the slowdown.
There are some approaches I can take to counteract that, but may not be worth the effort.
*/
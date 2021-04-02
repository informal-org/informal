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
    else if list.len() < 16 {
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
            // Optimization: Prepend (incurring the array shift cost) onto the previous pivot if the array is small.
            if pivots.len() > 0 && pivots.last().unwrap().len() <= 8 {
                // Insert the previous pivot into the proper place in the vector
                let previousPivot = pivots.last().unwrap()[0];
                binary_insert(&mut pivots[pivotIdx - 1], previousPivot);
                pivots.last_mut().unwrap()[0] = *elem;   // Set the new pivot
            } else {
                // Create a new pivot if it's too expensive to shift the old one.
                let mut subVec: Vec<u64> = Vec::with_capacity(16);
                subVec.push(*elem);
                pivots.push(subVec)                
            }

        } else {
            // println!("Binary inserting into arr");
            binary_insert(&mut pivots[pivotIdx], *elem);
        }
    }

    // Read the resulting array out in sorted order.
    let mut sorted: Vec<u64> = Vec::with_capacity(list.len());
    // println!("Pivots {:?}", pivots);
    for arr in pivots.iter() {
        if arr.len() >= 16 {
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

const HEAP_LEN: usize = 16;

struct Heap {
    pivot: u64,
    left_arr: Vec<u64>,
    left_heap: Box<Option<Heap>>,

    right_arr: Vec<u64>,
    right_heap: Box<Option<Heap>>
}

fn init_heap(pivot: u64) -> Heap {
    return Heap { 
        pivot: pivot,
        left_arr: Vec::with_capacity(HEAP_LEN),
        left_heap: Box::new(Option::None),
        right_arr: Vec::with_capacity(HEAP_LEN),
        right_heap: Box::new(Option::None)
    }
}


fn heap_insert(heap: &mut Heap, element: u64) {
    if element <= heap.pivot {
        // If the array isn't full, insert into it.
        // if heap.left_arr.len() < HEAP_LEN {
        //     let idx = heap.left_arr.binary_search(&element).unwrap_or_else(|x| x);
        //     heap.left_arr.insert(idx, element);
        // } else if heap.left_heap.is_none() {
        //     heap.left_heap = Box::new(Option::Some(init_heap(element)));
        // } else {
        //     heap_insert(&heap.left_heap.unwrap(), element)
        // }

        match heap.left_heap.as_mut() {
            Option::None => {
                if heap.left_arr.len() < HEAP_LEN {
                    let idx = heap.left_arr.binary_search(&element).unwrap_or_else(|x| x);
                    heap.left_arr.insert(idx, element);
                } else {    // Time to split the heap
                    // The midpoint is likely to be a good pivot since this array is already sorted.
                    let midpoint = heap.left_arr.len() / 2;
                    let mut left_heap = init_heap(heap.left_arr[midpoint]);
                    left_heap.left_arr.extend_from_slice(&heap.left_arr[0..midpoint]);
                    left_heap.left_arr.extend_from_slice(&heap.left_arr[midpoint + 1..]);
    
                    heap_insert(&mut left_heap, element);
                    heap.left_heap = Box::new(Option::Some(left_heap));
                }
            },
            Option::Some(left) => {
                heap_insert(left, element);
            }
        }
    } else {
        // Right

        match heap.right_heap.as_mut() {
            Option::None => {
                if heap.right_arr.len() < HEAP_LEN {
                    let idx = heap.right_arr.binary_search(&element).unwrap_or_else(|x| x);
                    heap.right_arr.insert(idx, element);
                } else {    // Time to split the heap
                    // The midpoint is likely to be a good pivot since this array is already sorted.
                    let midpoint = heap.right_arr.len() / 2;
                    let mut right_heap = init_heap(heap.right_arr[midpoint]);
                    right_heap.left_arr.extend_from_slice(&heap.right_arr[0..midpoint]);
                    right_heap.right_arr.extend_from_slice(&heap.right_arr[midpoint + 1..]);

                    heap_insert(&mut right_heap, element);
                    heap.right_heap = Box::new(Option::Some(right_heap));
                }

            },
            Option::Some(right) => {
                heap_insert(right, element)
            }
        }


        // if heap.right_heap.is_none() {
        //     if heap.right_arr.len() < HEAP_LEN {
        //         let idx = heap.right_arr.binary_search(&element).unwrap_or_else(|x| x);
        //         heap.right_arr.insert(idx, element);
        //     } else {    // Time to split the heap
        //         // The midpoint is likely to be a good pivot since this array is already sorted.
        //         let midpoint = heap.right_arr.len() / 2;
        //         let mut right_heap = init_heap(heap.right_arr[midpoint]);
        //         right_heap.left_arr.extend_from_slice(&heap.right_arr[0..midpoint]);
        //         right_heap.right_arr.extend_from_slice(&heap.right_arr[midpoint + 1..]);

        //         heap_insert(&mut right_heap, element);
        //         heap.right_heap = Box::new(Option::Some(right_heap));
        //     }
        // } else {
        //     heap_insert(&mut heap.right_heap.unwrap(), element)
        // }
    }
}

fn copy_to_array(heap: &Heap, vec: &mut Vec<u64>) {
    // if heap.left_heap.is_none() {
    //     vec.extend_from_slice(&heap.left_arr);
    // } else {
    //     copy_to_array(&heap.left_heap.unwrap(), vec);
    // }

    match heap.left_heap.as_ref() {
        Option::None => vec.extend_from_slice(&heap.left_arr),
        Option::Some(left) => copy_to_array(&left, vec)
    }


    vec.push(heap.pivot);

    match heap.right_heap.as_ref() {
        Option::None => vec.extend_from_slice(&heap.right_arr),
        Option::Some(right) => copy_to_array(&right, vec)
    }
}

fn heap_array_sort(list: &[u64]) -> Vec<u64> {
    let mut heap = init_heap(list[0]);
    for elem in list {
        heap_insert(&mut heap, *elem);
    }
    let mut sorted: Vec<u64> = Vec::with_capacity(list.len());
    copy_to_array(&heap, &mut sorted);
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


    #[bench]
    fn bench_heap_array_sort(b: &mut Bencher) {
        // println!("Testing gensort");
        b.iter(|| {
            let mut arr = gensort(BENCH_SIZE);
            let result = heap_array_sort(&arr[..]);
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

Tried to fix the problem of small buckets with a few elements by having it merge with the previous
bucket on insert in some cases, giving a min bucket size.

Did not make a big different. (Max bucket size of 8. Seemed to be the sweet spot)

test sort::tests::bench_graph_sort ... bench:     906,551 ns/iter (+/- 35,091)
test sort::tests::bench_std_sort   ... bench:     345,090 ns/iter (+/- 1,171)

Tried out a buffered heap sort (buffer size of 16)
test sort::tests::bench_graph_sort      ... bench:     911,466 ns/iter (+/- 9,835)
test sort::tests::bench_heap_array_sort ... bench:   1,302,285 ns/iter (+/- 29,507)
test sort::tests::bench_std_sort        ... bench:     347,782 ns/iter (+/- 4,698)


*/
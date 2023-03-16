use crate::structs::{Runtime, Atom, SymbolAtom};
use std::time::{SystemTime, UNIX_EPOCH};
use std::collections::BTreeMap;
use crate::constants::*;
use crate::utils::{create_string_pointer, create_pointer_symbol, truncate_symbol};


#[inline(always)]
fn get_interpolation_step(lookup_symbol: u64, mid: usize, mid_symbol: u64, min_index: usize, min_symbol: u64, max_index: usize, max_symbol: u64) -> usize {
    let mut low: u64;
    let mut high: u64;
    let mut low_symbol: u64;
    let mut high_symbol: u64;

    if min_symbol != 0 {
        low = min_index as u64;
        high = mid as u64;

        low_symbol = min_symbol;
        high_symbol = mid_symbol;
    } else {
        // Max_symbol != 0
        low = mid as u64;
        high = max_index as u64;

        low_symbol = mid_symbol;
        high_symbol = max_symbol;
    }

    return ( (lookup_symbol - low_symbol) * (high - low) / (high_symbol - low_symbol) ) as usize;
}



#[cfg(test)]
mod tests {
    use super::*;
    extern crate test;
    use eytzinger::SliceExt;

    use test::Bencher;
    pub const BENCH_SIZE: u64 = 1_000;
    // 10 reads per entry. 
    // Currently evenly distributed reads, but real usage would be biased towards the end like a stack
    pub const READ_MULTIPLIER: u64 = 10;


    fn pseudo_random() -> u64 {
        // Between 0 and 1 billion
        let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .subsec_nanos();
        return nanos as u64;
    }


    // // 10: 312 ns/iter (+/- 1)
    // // 100: 5,646 ns/iter (+/- 6)
    // // 1000: 82,179 ns/iter (+/- 589)
    // // 10_000: 1,060,700 ns/iter (+/- 2,959)
    // // 100_000: 13,479,786 ns/iter (+/- 128,964)
    // #[bench]
    // fn bench_binary(b: &mut Bencher) {
    //     let mut next_symbol = APP_SYMBOL_START;
    //     let mut runtime: Vec<SymbolAtom> = Vec::new();

    //     for _ in 0..BENCH_SIZE {
    //         // runtime.save_atom(Atom::NumericValue(999.0));
    //         let symbol = create_pointer_symbol(next_symbol);
    //         let value = SymbolAtom {
    //             symbol: symbol,
    //             atom: Atom::NumericValue(999.0)
    //         };
    //         runtime.push(value);
    //         next_symbol = next_symbol + 1 + ((pseudo_random() % 1000) as u64);
    //     }
    //     b.iter(|| {
    //         for i in 0..(BENCH_SIZE * READ_MULTIPLIER) {
    //             let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + (i % BENCH_SIZE));

    //             let mut min_index: usize = 0;
    //             let mut max_index = runtime.len();

    //             while min_index < max_index {
    //                 let mid = ((min_index + max_index) / 2) as usize;
    //                 let mid_symbol = runtime[mid].symbol;

    //                 if mid_symbol < lookup_symbol {
    //                     min_index = (mid + 1) as usize;
    //                 } else if mid_symbol > lookup_symbol {
    //                     max_index = (mid - 1) as usize;
    //                 } else {
    //                     // mid_symbol == lookup_symbol 
    //                     break;
    //                 }
    //             }
    //         }
    //     });
    // }


    // // 10: 390 ns/iter (+/- 0)
    // // 100: 6,288 ns/iter (+/- 9)
    // // 1000: 78,182 ns/iter (+/- 969)
    // // 10_000: 1,127,922 ns/iter (+/- 5,571)
    // // 100_000: 16,123,814 ns/iter (+/- 6,098)
    // #[bench]
    // fn bench_binary_heap(b: &mut Bencher) {
    //     let mut next_symbol = APP_SYMBOL_START;
    //     let mut runtime: BTreeMap<u64, u64> = BTreeMap::new();


    //     for _ in 0..BENCH_SIZE {
    //         // runtime.save_atom(Atom::NumericValue(999.0));
    //         let symbol = create_pointer_symbol(next_symbol);
    //         // let value = SymbolAtom {
    //         //     symbol: symbol,
    //         //     atom: Atom::NumericValue(999.0)
    //         // };
    //         runtime.insert(symbol, symbol);
    //         next_symbol = next_symbol + 1 + ((pseudo_random() % 1000) as u64);
    //     }
    //     b.iter(|| {
    //         for lookup_index in 0..(BENCH_SIZE*READ_MULTIPLIER) {
    //             let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + (lookup_index % BENCH_SIZE));
                
    //             // Rough implementation. May have bugs. Just getting order-of-magnitude perf
    //             runtime.get(&lookup_symbol);
    //         }
    //     });
    // }    





    // // 10: 206 ns/iter (+/- 1)
    // // 100: 2,992 ns/iter (+/- 3)
    // // 1000: 46,483 ns/iter (+/- 378)
    // // 10_000: 676,821 ns/iter (+/- 2,061)
    // // 100_000: 7,744,239 ns/iter (+/- 4,476)
    // #[bench]
    // fn bench_branchless_binary(b: &mut Bencher) {
    //     let mut next_symbol = APP_SYMBOL_START;
    //     let mut runtime: Vec<u64> = Vec::new();

    //     for _ in 0..BENCH_SIZE {
    //         // runtime.save_atom(Atom::NumericValue(999.0));
    //         let symbol = create_pointer_symbol(next_symbol);
    //         // let value = SymbolAtom {
    //         //     symbol: symbol,
    //         //     atom: Atom::NumericValue(999.0)
    //         // };
    //         runtime.push(symbol);
    //         next_symbol = next_symbol + 1 + ((pseudo_random() % 1000) as u64);
    //     }
    //     b.iter(|| {
    //         for lookup_index in 0..(BENCH_SIZE * READ_MULTIPLIER) {
    //             let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + (lookup_index % BENCH_SIZE));
                
    //             // Rough implementation. May have bugs. Just getting order-of-magnitude perf
    //             let mut index = runtime.len();
    //             let mut base = 0;
    //             while index > 1 {
    //                 let half = index / 2;
    //                 base = if runtime[half] < lookup_symbol { half } else { base };
    //                 index -= half;
    //             }
    //         }
    //     });
    // }

    // Baseline 10x read
    // 10: 44 ns/iter (+/- 0)
    // 100: 447 ns/iter (+/- 0)
    // 1000: 4,813 ns/iter (+/- 38)
    // 10_000: 38,724 ns/iter (+/- 83)
    // 100_000: 480,823 ns/iter (+/- 533)
    // 100_000 @50x read: 2,404,404 ns/iter (+/- 9,823)
    // 1M @ 5X read: 1,937,014 ns/iter (+/- 15,230)
    // 1M: 3,874,791 ns/iter (+/- 94,610)
    #[bench]
    fn bench_direct(b: &mut Bencher) {
        let mut next_symbol = APP_SYMBOL_START;
        let mut runtime: Vec<SymbolAtom> = Vec::new();

        for i in 0..BENCH_SIZE {
            // runtime.save_atom(Atom::NumericValue(999.0));
            let value = SymbolAtom {
                symbol: create_pointer_symbol(APP_SYMBOL_START + i),
                atom: Atom::NumericValue(999.0)
            };
            runtime.push(value);
        }
        b.iter(|| {
            let symbol = create_pointer_symbol(APP_SYMBOL_START);
            for i in 0..(BENCH_SIZE * READ_MULTIPLIER) {
                let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + (i % BENCH_SIZE));

                let index = (truncate_symbol(lookup_symbol) - truncate_symbol(symbol)) as usize;

                let value = &runtime[index];
                if value.symbol == lookup_symbol {
                    value.symbol;
                }
            }
        });
    }





    // 10: 202 ns/iter (+/- 0)
    // 100: 3,824 ns/iter (+/- 88)
    // 1000: 146,471 ns/iter (+/- 4,197)
    // 10_000: 2,950,779 ns/iter (+/- 7,388)

    // Binary heap - Eytzinger layout
    // https://arxiv.org/pdf/1509.05053.pdf
    // TODO: Fuzz test this. Too complex to test with regular test cases
    // #[bench]
    // fn bench_eytzinger2(b: &mut Bencher) {
    //     let mut next_symbol = APP_SYMBOL_START;
    //     let mut runtime: Vec<u64> = Vec::new();

    //     for _ in 0..BENCH_SIZE {
    //         let symbol = create_pointer_symbol(next_symbol);

    //         runtime.push(symbol);
    //         // next_symbol = next_symbol + 1 + ((pseudo_random() % 1000) as u64);
    //         next_symbol = next_symbol + 1;
    //     }

    //     runtime.eytzingerize(&mut eytzinger::permutation::InplacePermutator);
    //     // Values at this point are in a breadth-first order.
    //     // Index 0 = root = midpoint
    //     // left = 2i + 1 and right = 2i + 2
    //     // [0, 1, 2, 3, 4, 5, 6];
    //     // [3, 1, 5, 0, 2, 4, 6];

    //     b.iter(|| {
    //         for lookup_i in 0..(BENCH_SIZE*READ_MULTIPLIER) {
    //             let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + (lookup_i % BENCH_SIZE));
    //             let trunc_look = truncate_symbol(lookup_symbol) as i32;

    //             let mut min_dist: i32 = 0;
    //             let mut max_dist = runtime.len() as i32;
    //             let mut mid_dist = (min_dist + max_dist) / 2;


    //             let mut min_symbol = 0;
    //             let mut max_symbol = 0;
    //             let mut mid_symbol;

    //             let mut mid = 0;
    //             let mut next_mid;

    //             mid_symbol = runtime[mid];

    //             if lookup_symbol > mid_symbol {
    //                 // It will be on right side of tree
    //                 min_symbol = truncate_symbol(mid_symbol);
    //                 min_dist = (max_dist / 2) + 1;
    //                 next_mid = 2;       // 2 * 0 + 2
    //             } else if lookup_symbol < mid_symbol {
    //                 // It will be on the left side of tree
    //                 max_symbol = truncate_symbol(mid_symbol);
    //                 // Index here is more of a distance
    //                 max_dist = (max_dist / 2) - 1;
    //                 next_mid = 1;         // 2 * 0 + 1
    //             } else {
    //                 continue;
    //             }
    //             // So this is essentially always min_dist + max_dist / 4
    //             mid_dist = (min_dist + max_dist) / 2 as i32;

    //             mid = next_mid;
    //             if next_mid >= runtime.len()  {
    //                 continue;
    //             }

    //             mid_symbol = runtime[mid];
    //             let mut low: i32;
    //             let mut high: i32;
    //             let mut low_symbol: i32;
    //             let mut high_symbol: i32;

    //             if lookup_symbol == mid_symbol {
    //                 continue;
    //             }

    //             // Set interpolation endpoints based on previous observation
    //             if min_symbol != 0 {
    //                 low = min_dist;
    //                 high = mid_dist;

    //                 low_symbol = min_symbol as i32;
    //                 high_symbol = truncate_symbol(mid_symbol) as i32;
    //             } else {
    //                 // Max_symbol != 0
    //                 low = mid_dist;
    //                 high = max_dist;

    //                 low_symbol = truncate_symbol(mid_symbol) as i32;
    //                 high_symbol = max_symbol as i32;
    //             }

    //             let step = ( (trunc_look - low_symbol).abs() / (high_symbol - low_symbol) );

    //             if lookup_symbol > mid_symbol {
    //                 // It's in the range of Mid -> End
    //                 // But this time, with two points we know something more about the distribution based on what we found from previous turn
    //                 // So rather than going to midpoint, interpolate closer to where we guess the value will be.
    //                 // Adjust interpolation by interpolation step
    //                 // mid = mid + ( (trunc_look - low_symbol) * (high - low) / (high_symbol - low_symbol) );

    //                 mid = 2 * mid + 2;
    //             } else {
    //                 // Value is in the range of Start -> Mid
    //                 // mid = mid - ( (trunc_look - low_symbol) * (high - low) / (high_symbol - low_symbol) );
    //                 mid = 2 * mid + 1;
    //             }

    //             // TODO: Interpolation of mid


    //             // Binary search. TODO: Branchless version
    //             let mut i = mid;
    //             while i < runtime.len() {
    //                 let elem = runtime[i];
    //                 if lookup_symbol < elem {
    //                     i = 2 * i + 1;
    //                 } else if lookup_symbol > elem {
    //                     i = 2 * i + 2;
    //                 }
    //                 else {
    //                     break;
    //                 }
    //             }

    //         }
    //     });        
    // }    


    // Baseline 10x read
    // 10: 403 ns/iter (+/- 0)
    // 100: 4,156 ns/iter (+/- 4)
    // 1000: 47,066 ns/iter (+/- 415)
    // 10_000: 541,318 ns/iter (+/- 1,137)
    // 100_000: 10,822,811 ns/iter (+/- 318,222)
    // 100k @ 50x read: 48,145,003 ns/iter (+/- 776,457)
    // 1M @5x Read: 113,014,185 ns/iter (+/- 581,133)
    // 1M: 227,021,336 ns/iter (+/- 1,044,553)
    #[bench]
    fn bench_hash(b: &mut Bencher) {
        let mut runtime = Runtime::new(APP_SYMBOL_START);
        for i in 0..BENCH_SIZE {
            runtime.save_atom(Atom::NumericValue(999.0));
        }
        b.iter(|| {
            for i in 0..(BENCH_SIZE*READ_MULTIPLIER) {
                let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + (i % BENCH_SIZE));
                runtime.get_atom(lookup_symbol);
            }
        });
    }


    // Baseline 10x read
    // 10: 106 ns/iter (+/- 0)
    // 100: 1,002 ns/iter (+/- 1)
    // 1000: 9,964 ns/iter (+/- 137)
    // 10_000: 95,877 ns/iter (+/- 63)
    // 100_000: 1,106,378 ns/iter (+/- 3,466)
    // 100k @ 50x read: 5,531,458 ns/iter (+/- 3,522)
    // 1M @5x: 4,793,752 ns/iter (+/- 10,330)
    // 1M: 9,587,782 ns/iter (+/- 85,797)
    #[bench]
    fn bench_interpolated_binary(b: &mut Bencher) {
        let mut next_symbol = APP_SYMBOL_START;
        let mut runtime: Vec<SymbolAtom> = Vec::new();

        for _ in 0..BENCH_SIZE {
            let symbol = create_pointer_symbol(next_symbol);
            let value = SymbolAtom {
                symbol: symbol,
                atom: Atom::NumericValue(999.0)
            };
            runtime.push(value);
            next_symbol = next_symbol + 1 + ((pseudo_random() % 1000) as u64);
            // next_symbol = next_symbol + 1;
        }
        b.iter(|| {
            for i in 0..(BENCH_SIZE*READ_MULTIPLIER) {
                let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + (i % BENCH_SIZE));
                let mut min_index: usize = 0;
                let mut max_index = runtime.len();

                // Interpolation points saved as we discover info
                let mut min_symbol = 0;
                let mut max_symbol = 0;
                let mut mid_symbol;

                // In the beginning we have absolutely no information about where anything is
                // So the best place to check to get the maximum info is the middle
                // If we know additional info like the start value or the end value or any point
                // jump to interpolation. Otherwise, start similar to binary search.
                let mut mid = max_index / 2;
                
                // Unrolled first iteration. Check elem at mid index.
                // mid_symbol = runtime[mid].symbol;
                mid_symbol = runtime[mid].symbol;
                if lookup_symbol > mid_symbol {
                    // It's in the range of Mid -> End
                    // We could set it to the end of the list, but again the best place to extract maximum info is the midpoint
                    min_index = mid + 1;
                    // Save the value so we can interpolate with it later
                    // min_symbol = truncate_symbol(mid_symbol);
                    min_symbol = mid_symbol;
                } else if lookup_symbol < mid_symbol {
                    max_index = mid - 1;
                    // max_symbol = truncate_symbol(mid_symbol);
                    max_symbol = mid_symbol;
                } else {
                    // lookup_symbol == mid_symbol {
                    // We got lucky and found it. (Unlikely)
                    continue;
                }

                // Unrolled next iteration - this time using interpolation
                if min_index < max_index {
                    // Not found
                    continue;
                }
                mid = (min_index + max_index) / 2;
                // mid_symbol = runtime[mid].symbol;
                mid_symbol = runtime[mid].symbol;

                if lookup_symbol > mid_symbol {
                    // It's in the range of Mid -> End
                    // But this time, with two points we know something more about the distribution based on what we found from previous turn
                    // So rather than going to midpoint, interpolate closer to where we guess the value will be.                    
                    // let step = get_interpolation_step(trunc_look, mid, mid_symbol, min_index, min_symbol, max_index, max_symbol);
                    let step = get_interpolation_step(lookup_symbol, mid, mid_symbol, min_index, min_symbol, max_index, max_symbol);

                    min_index = mid + 1;
                    // Adjust interpolation by interpolation step
                    mid = mid + step;
                } else if lookup_symbol < mid_symbol {
                    // Value is in the range of Start -> Mid
                    // let step = get_interpolation_step(trunc_look, mid, mid_symbol, min_index, min_symbol, max_index, max_symbol);
                    let step = get_interpolation_step(lookup_symbol, mid, mid_symbol, min_index, min_symbol, max_index, max_symbol);

                    max_index = mid - 1;
                    mid = mid - step;
                } else {
                    // We got lucky and found it. (Unlikely)
                    continue;
                } 

                // Further stages of interpolation doesn't seem to add much benefit. Mostly overhead.
                // So switch to binary search at this point. (Binary better than linear even for small inputs)
                // Experimentation shows the branched version outperforming the branchless version here (664 vs 884)
                while min_index < max_index {
                    // mid_symbol = runtime[mid].symbol;
                    mid_symbol = runtime[mid].symbol;

                    if lookup_symbol > mid_symbol {
                        min_index = mid + 1;
                    } else if lookup_symbol < mid_symbol {
                        max_index = mid - 1;
                    } else {
                        // mid_symbol == lookup_symbol
                        break;
                    }
                    mid = (min_index + max_index) / 2;
                }

            }
        });
    }





    // // 10: 155 ns/iter (+/- 1)
    // // 100: 1,607 ns/iter (+/- 4)
    // // 1000: 19,957 ns/iter (+/- 383)
    // // 10_000: 589,993 ns/iter (+/- 23,883)
    // // 100_000: 48,723,974 ns/iter (+/- 123,903)
    // #[bench]
    // fn bench_linear(b: &mut Bencher) {
    //     let mut next_symbol = APP_SYMBOL_START;
    //     let mut runtime: Vec<SymbolAtom> = Vec::new();

    //     for i in 0..BENCH_SIZE {
    //         let symbol = create_pointer_symbol(next_symbol);
    //         let value = SymbolAtom {
    //             symbol: symbol,
    //             atom: Atom::NumericValue(999.0)
    //         };
    //         runtime.push(value);
    //         next_symbol = next_symbol + 1 + ((pseudo_random() % 1000) as u64);
    //     }
    //     b.iter(|| {
    //         for i in 0..(BENCH_SIZE*READ_MULTIPLIER) {
    //             let lookup_symbol = create_pointer_symbol(APP_SYMBOL_START + (i % BENCH_SIZE));

    //             for index in 0..BENCH_SIZE {
    //                 let value = &runtime[index as usize];
    //                 if value.symbol > lookup_symbol {
    //                     break;
    //                 } else if value.symbol == lookup_symbol {
    //                     value.symbol;
    //                     break;
    //                 }
    //             }
    //         }
    //     });
    // }


}


from typing import List

def compute_hash(target: List[int]):
    distinct = max(target) + 1
    for M in range(0, 1000):
        offsets = []
        matches = True
        for i in range(0, len(target)):
            if ((i + 1) * M) % distinct == target[i]:
                offsets.append(0)
            elif ((i + 2) * M) % distinct == target[i]:
                offsets.append(1)
            else:
                matches = False
                continue
        if matches:
            return M, offsets
    return None, None


0, 1, 2, 3
1, 0, 3, 2
print(compute_hash([1, 0, 3, 2]))
f(0) = 1
f(1) = 0
f(2) = 3
f(3) = 2

LOAD table / table + 1 depending on charcode.
POPCNT - matches / not
LOAD first half table bitset.
INDEX into table. If 1, then your value is in the first half.
    POPCNT - index into first half of possible values.
else…
    It's in the second half of possible values.
    LOAD second half table bitset.
    POPCNT - 0 = most popular value. 1 = index into the result array.


How about this...
A series of bitsets.
First one tells you if you match or not. Popcount that to get your index.
Then a bitset - if you match 1, then index into an array by its popcount.
If 0, check the next bitset.

Two ways to use the bitset - it's either every possibility that matches a single value.
Or just indicates matching from a set of distinct values, but then you have to index into it.


# Let's flip it so that the most common case is fastest.
# LOAD
# BITSET [charcode] - match / not.
# POPCNT -> Index
# Bitset [index]
# If 0:
#     Most popular value
# If 1:

# NOPE. can't flip it. That'd only give us one bit of useful info, versus doing the which half of distinct values test first gives us more info.

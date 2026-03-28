#!/usr/bin/env python3
"""Generate random arithmetic source code for benchmarking the compiler.

Usage:
    python generate.py <n_lines> <output_file>

Example:
    python generate.py 10000 bench_input.ifi
"""

import random
import sys


def random_number():
    return str(random.randint(1, 999))


def random_var():
    return chr(random.randint(ord("a"), ord("z")))


OPS = ["+", "-", "*", "/", "%"]


def random_op():
    return random.choice(OPS)


def generate_expr(depth):
    # Base case: atom (number or variable reference)
    if depth == 0 or random.random() < 0.35:
        return random_number() if random.random() < 0.5 else random_var()

    left = generate_expr(depth - 1)
    right = generate_expr(depth - 1)
    op = random_op()

    # ~15% chance of parenthesized sub-expression
    if random.random() < 0.15:
        return f"({left}{op}{right})"

    return f"{left}{op}{right}"


def generate_line():
    var = random_var()
    expr = generate_expr(depth=4)
    return f"{var}={expr}"


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <n_lines> <output_file>", file=sys.stderr)
        sys.exit(1)

    n_lines = int(sys.argv[1])
    output_file = sys.argv[2]
    seed = 42
    random.seed(seed)

    lines = [generate_line() for _ in range(n_lines)]
    source = "\n".join(lines)

    with open(output_file, "w") as f:
        f.write(source)

    print(f"Generated {n_lines} lines, {len(source)} bytes -> {output_file}", file=sys.stderr)


if __name__ == "__main__":
    main()

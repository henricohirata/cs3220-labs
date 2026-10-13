# Lab 3 Test Generator | Student Guide

## What is this file?

`gen_revamp_tests.py` is a **test maker**. You do not hand-write `.mem` hex files (that would probably be torture). You implement Python logic that describes a program (operands, expected results), and this tool emits the `.mem` file the simulator already knows how to run.

You can think of it like wee lil compiler: **your Python → `.mem` → `./run_tests.sh`**.

## What you implement (take-home)

Only two functions in this file are yours, search for the `TODO (take-home)` block and implement `rand_exact_op` & `gen_random_stress` beneath it. Everything else is scaffolding you inherit as-is (encoders, `Prog`, `emit`, `build_ops_test`, `f2h`).

| Function | Your job |
|----------|----------|
| `rand_exact_op(rng)` | Pick one random DIV or MULT with an **exact** float32 result |
| `gen_random_stress(...)` | Build a list of N random ops and call `build_ops_test(...)` |

The TODOs inside those functions are **worded step lists** (no solution code). Read them first if Python feels rusty compared to the RTL work from earlier labs.

Good news: you do **not** need to write RISC-V assembly by hand; `build_ops_test` does that once you give it the op list.

## Why "exact" operands?

A random test still needs to know the right answer to check against. Pick operands whose true result fits exactly in 32-bit float so your baked-in `expected_hex` always matches the ALU:

- **MULT:** small integers `m1 * m2` (product &lt; 2²⁴ is exact)
- **DIV:** pick quotient `q` and divisor `d`, use dividend `q*d`, then `q*d / d = q`

## Steps

1. **Open** `test/tools/gen_revamp_tests.py` (look for the `TODO:` block)
2. **Implement** `rand_exact_op` and `gen_random_stress`
3. **Generate** your test:
   ```bash
   python3 test/tools/gen_revamp_tests.py --seed 1234
   ```
   (use a personal seed, so use your GT ID)
4. **Check** output appeared in `test/student/random_stress.mem`
5. **Simulate**:
   ```bash
   ./run_tests.sh student
   ```
6. **Write-up:** include your seed, a snippet from `random_stress.lst`, and what happens when you change the seed (still passes if your HDL is correct)

## What you turn in

- Your HDL (`de_stage.v`, etc.)
- Your completed `gen_revamp_tests.py` (`rand_exact_op` & `gen_random_stress` filled in)
- The generated `test/student/random_stress.mem` (and optionally `.lst`)
- Write-up referencing your personalized test

TAs keep separate hidden tests for grading, you won't get those `.mem` files.

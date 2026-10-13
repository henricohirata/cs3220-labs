# Your randomized stress test goes here!

This folder is **supposed to be empty when you start**. You fill it by implementing the take-home random test in `test/tools/gen_revamp_tests.py` (the two `TODO` functions have **step-by-step word hints**, no solution code) and running the generator (see `test/tools/README.md`).

After generation you should see files like:

```
test/student/random_stress.mem   <= what the simulator loads
test/student/random_stress.lst   <= human-readable listing (for your write-up)
test/student/random_stress.S     <= optional rebuild with course toolchain
```

Run your test the same way as the public part tests:

```bash
cd <your_lab_root>
python3 test/tools/gen_revamp_tests.py --seed <your_seed>
./run_tests.sh student
```

Use a seed that is unique to you (e.g. your GT ID) so your test is personalized. A correct HDL implementation should pass **whatever** seed you pick, as long as your generator picks operands with exact float32 results.

**Do not** copy a finished `.mem` from a friend, the write-up asks you to explain your own generator choices.

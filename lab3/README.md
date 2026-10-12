# CS3220 Lab #3 : A Case Study of A RISC-V with An External ALU

110 pts in total, will be rescaled into 15% of your final score of the course.  

**In-class: Connect An External ALU with A RISC-V**: 45 pts

**Take-home: HDL Correctness + Randomized Test**: 35 pts

**Take-home: Cycle Budget**: 5 pts

**Take-home: Write-up + AI Investigation**: 15 pts

**Bonus**: 10 pts

***Submission ddl***: October 23rd, 2026 at 11:59 PM

This lab builds upon the knowledge you've gained from previous lectures and labs on RISC-V CPU design. Specifically, you'll be integrating the RISC-V CPU you designed in earlier labs with an external ALU to enhance its efficiency for certain complex workloads.

The lab is split into an **in-class** session and a **take-home** portion. In class you instantiate the external ALU in the FU stage, connect it through the DE↔FU buses, and complete one correct DIV handshake in decode with NOP spacing between operand loads. At home you remove those assumptions: handle ALU readiness stalls, pass a broader public test set, build your own randomized stress test, meet a cycle budget, and submit a short write-up that shows you understand the handshake well.

## External ALU + RISC-V mailbox (reference for both portions)

The [external ALU](external_alu_wrapper.v) has following specifications:
<!-- * `OPREG1`, `OPREG2`, and `OPREG3` are 5-bit inputs that specify the registers to be used as operands for the ALU operation.
    * 4 registers for each of them; in total 12 registers -->
* `OP1` and `OP2` are 32-bit inputs that specify the values to be used as operands for the ALU operation. (Floating point numbers in IEEE 754 format)
* `OP3` is a 32-bit output that holds the result of the ALU operation. (Floating point numbers in IEEE 754 format)
* `ALUOP` is a 4-bit input that specifies the ALU operation to be performed. The ALUOP values are as follows:
    * 0001: DIV
    * 0010: MULT
    <!-- * `ALUOP[3]` is a 1-bit input that specifies whether the ALU operation is signed or unsigned. If `ALUOP[3]` is 0, the operation is unsigned; if `ALUOP[3]` is 1, the operation is signed. -->
* `CSR_ALU_OUT` (Control/Status Register) is a 3-bit input port that represents the status of the ALU operation. The `CSR_ALU_OUT` values are as follows:
    * `CSR_ALU_OUT[0]` is a 1-bit output that signals if the ALU OP1 port is READY/BUSY
        * i.e. whether the ALU will be able to latch in your inputs (operands and ALUOP)
    * `CSR_ALU_OUT[1]` is a 1-bit output that signals if the ALU OP2 port is READY/BUSY
        * i.e. whether the ALU will be able to latch in your inputs (operands and ALUOP)
    * `CSR_ALU_OUT[2]` is a 1-bit output that signals if the result of the ALU operation is VALID/INVALID
        * 1: VALID; 0: INVALID
* `CSR_ALU_IN` is a 3-bit output that control the status of the ALU operation. The `CSR_ALU_IN` values are as follows:
    * `CSR_ALU_IN[0]` is a 1-bit input that signals the the results can be overwritten by the ALU.
        * When set to 1, it acknowledges the ALU that the output is received and can be overwritten in following cycles; thus the output will become unstable
        * After reading the output, you may also want to set `CSR_ALU_IN`[0] back to 0, so you can catch the results when it's stable
        * reference: [divider.v](divider.v#L294)
    * `CSR_ALU_IN[1]` is a 1-bit input that signals the `OP1` fed to the ALU is stable
        * If it's set to 1, the ALU will latch in the `OP1` value; otherwise, the ALU will stall the current operation and wait for `OP1` to be stable
        * It's ignored if the ALU is not ready to accept `OP1`
    * `CSR_ALU_IN[2]` is a 1-bit input that signals the `OP2` fed to the ALU is stable
* The `ALUOP` need to be loaded first and the operands `OP1` and `OP2` need to be loaded in order
* The ALU is data driven, i.e. it will start the computation as soon as the operands are loaded, based on the loaded ALUOP
* Potential delay between the two operands' loading, i.e. ALU can potentillay not be ready to load `OP2` when `OP1` is loaded
* The ALU is adapted from this implementation:
    * https://github.com/dawsonjon/fpu
    * https://dawsonjon.github.io/Chips-2.0/language_reference/interface.html 

The specifications from RISC-V CPU is as follows:

1. For loading the operands, we will use `LW` instructions, to load the operands from the memory, with dst reg ID:
    * 11110: `OP1`
    * 11111: `OP2`
2. For loading the `ALUOP` to configure the ALU, we will use `LW` instructions, with dst reg ID
    * 11101: `ALUOP`
4. For reading the result/status from the ALU, we will use `SW` instructions, with src reg ID
    * 11011: `OP3`
    * 11010: `CSR_ALU_OUT`
5. Intended instruction sequence:
    * load `ALUOP` 
    * load `OP1`, `OP2` (**`OP1` and `OP2` need to be loaded in order**)
    * store `OP3`

### Waveform reference (in-class)

We provide a finished handshake waveform so you can see what “correct” looks like before you invent a control recipe from the README alone.

* VCD: [artifacts/waveform/lab3_inclass_handshake.vcd](artifacts/waveform/lab3_inclass_handshake.vcd)
* GTKWave preset (signals + zoom pre-loaded): [artifacts/waveform/lab3_inclass_handshake.gtkw](artifacts/waveform/lab3_inclass_handshake.gtkw)
* Example screenshots: [artifacts/waveform/screenshots/](artifacts/waveform/screenshots/)

Open with:

```bash
gtkwave artifacts/waveform/lab3_inclass_handshake.vcd artifacts/waveform/lab3_inclass_handshake.gtkw
```

Zoom in and scroll to study the operand-load sequence and the result store / CSR ack timing. Your write-up should include screenshots from **your** implementation, but you may compare against this reference.


## In-Class: Connect An External ALU with A RISC-V (45 points): 

In this section, you'll integrate the RISC-V CPU you designed in Lab #2 with a supplied external ALU. You will wire the FU stage in [FU_stage.v](FU_stage.v) and implement the decode-stage mailbox/handshake control in [de_stage.v](de_stage.v).

Your tasks are as follows:
1. Integrate the ALU with the RISC-V CPU. You will need to modify the RISC-V CPU to accommodate the ALU's operations.
    * Instantiate and wire `external_alu` in [FU_stage.v](FU_stage.v)
    * Implement the mailbox/handshake control in [de_stage.v](de_stage.v) (see the in-class TODOs; mailbox register indices and bus widths are in `define.vh`)
    * Study the provided waveform before writing control logic; there isn't a pre-wired controller (since you will be making it)
2. You can assume enough `NOP`s inserted to separate the operands loading and storing the results
    * In other words you don't need to worry about the stalls needed to handle the ALU's readiness during the in-class portion

To pass this part and earn full credit, implement the integration described above and run your implementation on the in-class tests and ensure they pass.
* Primary handshake test: [handshake_div.mem](test/public/inclass/handshake_div.mem) (one DIV → `3.0 / 1.5` with in-class NOP spacing)
* Scaffolded regression: [alutest0.mem](test/public/inclass/alutest0.mem)
* You can use `./run_tests.sh inclass` to test your implementation (there is also an alias `./run_tests.sh part5`)


## Take-Home: HDL Correctness + Randomized Test (35 points)

What if there is no `NOP`s inserted between OP1 loading and OP2 loading, and the ALU might not be ready to load either `OP1` or `OP2`? What if the instruction to store `OP3` is issued before the ALU finishes?

Modify the in-class implementation to handle the stalls needed to handle the ALU's readiness. Your implementation should still work on the in-class testcases.
* You may modify more files (except the [external ALU](external_alu_wrapper.v) and its dependent modules) as needed.

### Public Tests (Autograded)

To pass the public correctness portion, run your implementation on the take-home public tests:
* [alutest1.mem](test/public/takehome/alutest1.mem) → operand-ready stalls (prior part6)
* [alutest2.mem](test/public/takehome/alutest2.mem) → result-valid store stall (prior part7)
* [varied_ops.mem](test/public/takehome/varied_ops.mem) → mixed DIV/MULT with non-toy operands

```bash
./run_tests.sh takehome
```

Backward-compatible aliases: `./run_tests.sh part6`, `./run_tests.sh part7`

### Your Randomized Stress Test (Required)

You also implement a **personalized** random DIV/MULT test using [test/tools/gen_revamp_tests.py](test/tools/gen_revamp_tests.py). See [test/tools/README.md](test/tools/README.md) and [test/student/README.md](test/student/README.md).

1. Fill in `rand_exact_op` and `gen_random_stress` (see the `TODO:` block in [test/tools/gen_revamp_tests.py](test/tools/gen_revamp_tests.py)).
2. Generate with a seed unique to you (e.g. your GT ID):
   ```bash
   python3 test/tools/gen_revamp_tests.py --seed <your_seed>
   ```
3. Run:
   ```bash
   ./run_tests.sh student
   ```

A correct HDL solution should pass **whatever** seed you pick, as long as your generator uses exact-representable float32 operands. Submit your completed generator and the generated `test/student/random_stress.mem` (and optionally `.lst`).

**Test policy:** You receive **public** tests only. Additional hidden tests will exist for grading robustness, you will not get those `.mem` files before the deadline.


## Take-Home: Cycle Budget (5 points)

Correct function is not enough for full take-home credit. Your pipelined implementation should not stall excessively on the performance workload.

* Reference workload: `perf_budget` (will be a hidden test, but will show your number of cycles)
* **Cycle budget: 1350 cycles** (measured from our reference solution + margin)
* If you beat the budget on your local runs, thats great! Autograding will enforce this on the hidden perf test

There is no separate `./run_tests.sh` category for students on the perf workload. Treat the budget as a design target while developing your take-home solution. Document your cycle count on the public take-home tests in the write-up if helpful.


## Take-home: Write-up + AI Investigation (15 points)

Submit a short PDF (max 3 pages, single or double spaced, a typical free response writeup you'd submit for a class) alongside your code. Suggested sections:

1. **Handshake evidence** → Two GTKWave screenshots from **your** implementation: (a) operand load sequence, (b) result store/CSR ack. Label the CSR bits you were watching.
2. **Random test** → Your seed, one op line from `random_stress.lst`, and why exact-representable operands matter.
3. **AI investigation (required)** → Choose **one** of the following (you do **not** have to use an AI assistant if you prefer not to):
   * **Option A (use an AI):** Ask an AI assistant about some part of this lab (or have it attempt a piece of the implementation, **AFTER** your implementation). Paste or summarize one **wrong** suggestion it made (e.g. backwards CSR direction, “only ack on ALUOP reload”, skipping store stall). Explain why it is wrong using **your** implementation, waveform, or test behavior.
   * **Option B (no AI required):** If you prefer not to use an AI tool, infer a **non-obvious** mistake an AI would likely make if tasked with this handshake/controller (again: not a superficial style nitpick, something that would fail a real test or deadlock the ALU). Justify that inference from **your** implementation, waveform, stalls, or CSR timing.
   * **Optional Add-on (from either option):** If you have relevant experience, you may briefly discuss which kinds of AI/models you think could handle this design problem and which would struggle, and why (e.g. "Claude would go this route... and GPT would go this route..."). This is optional; skip it if you do not know or prefer not to comment, it's more of a "for fun" type of thing, we are happy to read about it!

The write-up is where you demonstrate understanding. Autograders check `.mem` pass/fail; TAs will spot-check write-ups for the investigation (Option A or B) and handshake screenshots.


## Bonus points (10 points)

This part is for students who want an extra challenge beyond the public take-home tests.

Implement a controller that survives **back-to-back operand streaming**: load ALUOP once, then issue multiple `OP1`/`OP2` pairs and stores **without** reloading ALUOP between pairs of the same operation type, while still acknowledging results so the ALU does not deadlock.

This is graded via hidden robustness tests (won't be in the public tests). If your design already handles take-home stalls correctly, you may earn bonus without extra commands; the autograder runs the hidden set after you submit.

Optional stretch goals (not separately point-allocated): divider edge cases (`1.0/0.0`, `0.0/0.0`), beating the cycle budget by a wide margin.


## Submission

+ Provide a zip file containing your HDL sources, completed `test/tools/gen_revamp_tests.py`, generated `test/student/random_stress.mem`, and your write-up PDF. Generate `submission.zip` with:
  ```bash
  python3 test/tools/gen_revamp_tests.py --seed <your_seed>
  # optional: place writeup.pdf in the lab root so make submit packs it, but its better to submit on Canvas
  make submit
  ```
  Avoid manual zip file creation to prevent any issues with the autograding script.
+ Submit `submission.zip` to Gradescope. In addition, **submit your report onto Canvas**. 

### Grading breakdown (100 + 10 bonus)

| Component | Points | How graded |
|-----------|--------|------------|
| In-class handshake (FU + DE) + inclass tests | 45 | Autograder: `./run_tests.sh inclass` |
| Take-home public + student random test | 35 | Autograder: `./run_tests.sh takehome` + `./run_tests.sh student` |
| Cycle budget | 5 | Hidden perf workload (1350 cycles) |
| Write-up + AI investigation | 15 | Manual / spot-check |
| **Bonus:** back-to-back streaming | 10 | Hidden robustness tests |
| **Total** | **110** | Rescaled to 15% course grade |


## Q&A (Courtesy from previous years' students' and TAs' Q&A)

**Q1. Under the RISC-V specifications, we are given destination and source register ids for using the LW and SW instructions, but I am a bit confused about its usage, for example to access OP3 for example do I do SW(11011)? And if so would this be done in the mem stage?**

A1. As the one making the processor, you don't have to issue any instructions. The details about SW and LW relate to what the programmer does to use the ALU. But it is your job to make sure that if there is a SW instruction with the specified register id, that the ALU and CPU are ready to transfer the output to the CPU or have already done so. In this case, the CSR signals are key to coordinating this.

**Q2. Are the registers for OP1, OP2, OP3, and ALUOP only ever used for this external ALU? Do we have to handle the case where these registers can be used as general purpose registers as well as registers for this external ALU or are we guaranteed that these registers are only ever used for external ALU computation?**

A2. For this lab, these registers (30, 31, 27, 29) are reserved only for external ALU operations.

**Q3. What is the overall strategy for implementing Lab 3?**

A3. Study the provided waveform and the CSR/operand timing for one DIV. Derive **your** control strategy in `FU_stage.v` and `de_stage.v` (and stalls for take-home) from what you see — we intentionally do not give a step-by-step FSM recipe in this README.

**Q4. I am modifying the DE stage for the in-class portion, and I saw comments about loading aluop → op1 → op2 → storing results. Are we supposed to invoke the external alu here?**

A4. The external ALU is able to invoke itself. Once it receives op1 and op2, it moves itself into the execute stage and does the calculation. This takes some amount of time, so the processor has to wait until the result is ready to bring it back to the CPU. The ALU is data-driven and automatically begins calculation once both operands are loaded based on the loaded ALUOP. Then you'll have to coordinate between the ALU and CPU to bring the result back. The in-class tests have enough NOPs in between the loadings and the store that you won't run into a case where the SW is issued, but the data isn't ready.

**Q5. Decode Stage store to memory. How would we store to memory in the decode stage as the TODO says "store results to memory"? I do not see anywhere to access the memory there.**

A5. The programmer will issue an SW instruction to store the result in register 27 to somewhere. By the time this instruction reaches DE, register 27 should contain the result from the ALU. If this instruction runs through, you've effectively stored the result to memory. The functionality to get the data from the ALU to CPU in register 27 is for us to implement.

**Q6. What's the difference between CSR_ALU_IN and CSR_ALU_OUT?**

A6. CSR_ALU_OUT is an input to your CPU (output from ALU) that shows ALU status. CSR_ALU_IN is an output from your CPU (input to ALU) that you control to tell the ALU what to do. Note: The README has this backwards (typo). These signals are themselves the ready/valid signals - it's not necessary to have another set of ready/valid signals to tell if they are ready/valid.

**Q7. The readme mentions that CSR_ALU_OUT can be saved to memory by the programmer. Do we assume that whatever value is in the designated register is the correct value, because there doesn't appear to be signals that indicate status stability. Do we assume the same thing for ALUOP? My understanding is the ALU will only latch to operands when CSR_ALU_IN[1,2] are set, but there is no signal for ALUOP. Do we assume that it can be loaded at any time?**

A7. (1) CSR_ALU_OUT and CSR_ALU_IN are themselves the signals to tell if the data signals are ready/valid. So you can somewhat assume it's "correct" whatever the value points to, but you need to be very certain when you read these signals. (2) Storing CSR_ALU_OUT is not necessary in THIS lab, so no worry about it. (3) For ALUOP, imagine a switch - the computation will carry on in a mode wherever the ALUOP is pointing to at that moment. And there is a default position for it, so if you do not load it, it will go to the default location. You should filter out ALUOP = 0, which is set during initialization and is invalid.

**Q8. How do I access ALUOP, OP1, OP2, and OP3 values in my implementation?**

A8. Use WB stage forwarding signals (`regval_WB` and `wregno_WB`). The programmer uses LW/SW instructions - your job is to ensure CPU and ALU coordinate properly using CSR signals. Values are stable after writeback to the register file - check CSR_ALU_OUT bits to confirm when to proceed.

**Q9. Do values need to be loaded in a specific order?**

A9. Yes - ALUOP must be loaded first, then OP1, then OP2 in that order. The ALU accepts inputs sequentially and may not be ready for OP2 when OP1 is loaded.

**Q10. In my FU, I am trying to figure out why my in-class test is not working and am curious as to why the FU stage all of a sudden gets a large number such as 3F800000 randomly in despite the numbers I manually provided?**

A10. The ALU performs floating-point operations in IEEE 754 format. Translate the value from HEX into floating point to verify correctness. For example, 0x3F800000 = 1.0 in floating point.

**Q11. What's the difference between in-class, take-home, and bonus?**

A11. 
* In-class (45 pts): NOP-spaced handshake; wire FU + DE mailbox control; pass `./run_tests.sh inclass`
* Take-home HDL (35 pts): Operand/result stalls; public takehome tests + your random test
* Take-home cycle budget (5 pts): Stay within 1350 cycles on the perf workload
* Take-home write-up (15 pts): Waveform proof + AI investigation (Option A or B)
* Bonus (10 pts): Back-to-back operand streaming under one ALUOP load (hidden tests)

**Q12. Where do I implement stalls for take-home?**

A12. In `de_stage.v`, stall when the ALU is not ready for the mailbox operation your decode stage is attempting. Use `CSR_ALU_OUT` together with your pipeline stall logic — derive the exact conditions from the waveform rather than copying a boolean from this README.

**Q13. My OP3 value is correct but appears too late. Why?**

A13. Common causes:
1. Extra register stages between DE and FU
2. Incorrect state transitions
3. Not properly checking CSR_ALU_OUT for completion
4. Using DE stage values instead of WB stage values

**Q14. How long should external ALU computation take?**

A14. Approximately 600-700 ps for one DIV. If significantly longer, check state transitions and CSR_ALU_IN settings.

**Q15. CSR_ALU_OUT never changes - what's wrong?**

A15. Check:
1. ALUOP is valid (not 0) - filter out initialization values
2. Using WB stage values (`wr_reg_WB`, `wregno_WB`, `regval_WB`), not DE stage values
3. CSR_ALU_IN bits are set correctly and sequentially
4. Check `external_alu_wrapper.v` signals in waveform viewer to verify inputs are being latched

**Q16. Register has correct value but test fails. What should I check?**

A16. This is a timing issue - the value must be in register 27 BEFORE the SW instruction executes. Trace timing in GTKWave to see when the value becomes available versus when SW reaches the pipeline stage that reads it.

**Q17. How do I debug in GTKWave?**

A17. Start with the provided [lab3_inclass_handshake.gtkw](artifacts/waveform/lab3_inclass_handshake.gtkw), then compare against your own run. Verify when inputs/outputs become valid, then trace signals backwards through pipeline stages. Check the register file (`regfile`) in DE stage to see when values are written.

**Q18. Which test command should I use for each portion?**

A18. 
* In-class: `./run_tests.sh inclass` (alias `part5`)
* Take-home public: `./run_tests.sh takehome` (aliases `part6`, `part7`)
* Your random test: `./run_tests.sh student`
* All public: `./run_tests.sh public`






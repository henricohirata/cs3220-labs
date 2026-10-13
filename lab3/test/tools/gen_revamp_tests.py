#!/usr/bin/env python3
"""
Lab 3 test generator.

Generates .mem (for $readmemh), .S (GNU as source, rebuildable with the course
RISC-V toolchain), and .lst (human-readable listing) for your take-home
randomized stress test.

This is a test *maker*: you implement Python logic that describes a program
(operands, expected results), and this tool emits the .mem file the simulator
already knows how to run.

Usage (take-home random test):
  cd <lab_root>
  python3 test/tools/gen_revamp_tests.py --seed <your_seed>
  ./run_tests.sh student
"""

import os
import struct
import random
import argparse

START_PC = 0x200
DATA_BASE = 0x800


def f2h(x):
    """IEEE-754 float32 bit pattern (as a 32-bit int) for a Python number."""
    return struct.unpack("<I", struct.pack("<f", float(x)))[0]


def addi(rd, rs1, imm):
    assert -2048 <= imm < 2048
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0010011

def lw(rd, rs1, imm=0):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0b0000011

def sw(rs2, rs1, imm=0):
    hi = (imm >> 5) & 0x7F
    lo = imm & 0x1F
    return (hi << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | (lo << 7) | 0b0100011

def lui(rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0b0110111

def bne(rs1, rs2, off):
    assert off % 2 == 0
    return (((off >> 12) & 1) << 31) | (((off >> 5) & 0x3F) << 25) | (rs2 << 20) | \
           (rs1 << 15) | (0b001 << 12) | (((off >> 1) & 0xF) << 8) | (((off >> 11) & 1) << 7) | 0b1100011

def jal(rd, off):
    assert off % 2 == 0
    return (((off >> 20) & 1) << 31) | (((off >> 1) & 0x3FF) << 21) | (((off >> 11) & 1) << 20) | \
           (((off >> 12) & 0xFF) << 12) | (rd << 7) | 0b1101111

NOP = addi(0, 0, 0)


class Prog:
    """Tiny two-pass assembler over a list of (kind, args) items."""

    def __init__(self):
        self.items = []   # ("insn", encoder-lambda, asm-text) | ("label", name)

    def label(self, name):
        self.items.append(("label", name))

    def insn(self, fn, text):
        self.items.append(("insn", fn, text))

    # convenience wrappers ------------------------------------------------
    def li(self, rd, imm, comment=""):
        """32-bit li, expands to addi or lui(+addi)."""
        imm &= 0xFFFFFFFF
        signed = imm - (1 << 32) if imm >= (1 << 31) else imm
        c = f" # {comment}" if comment else ""
        if -2048 <= signed < 2048:
            self.insn(lambda L: addi(rd, 0, signed), f"li x{rd}, {signed}{c}")
        else:
            hi20 = ((imm + 0x800) >> 12) & 0xFFFFF
            lo12 = imm - ((hi20 << 12) & 0xFFFFFFFF)
            lo12 = lo12 - (1 << 32) if lo12 >= (1 << 31) else lo12
            self.insn(lambda L: lui(rd, hi20), f"lui x{rd}, 0x{hi20:x}{c}")
            if lo12 != 0:
                self.insn(lambda L: addi(rd, rd, lo12), f"addi x{rd}, x{rd}, {lo12}")

    def lw_(self, rd, rs1, imm=0, comment=""):
        c = f" # {comment}" if comment else ""
        self.insn(lambda L: lw(rd, rs1, imm), f"lw x{rd}, {imm}(x{rs1}){c}")

    def sw_(self, rs2, rs1, imm=0, comment=""):
        c = f" # {comment}" if comment else ""
        self.insn(lambda L: sw(rs2, rs1, imm), f"sw x{rs2}, {imm}(x{rs1}){c}")

    def bne_(self, rs1, rs2, target):
        self.insn(lambda L, pc: bne(rs1, rs2, L[target] - pc),
                  f"bne x{rs1}, x{rs2}, {target}")

    def j_(self, target):
        self.insn(lambda L, pc: jal(0, L[target] - pc), f"j {target}")

    def nop(self, n=1):
        for _ in range(n):
            self.insn(lambda L: NOP, "nop")

    # assembly ------------------------------------------------------------
    def assemble(self, base=START_PC):
        labels = {}
        pc = base
        for it in self.items:
            if it[0] == "label":
                labels[it[1]] = pc
            else:
                pc += 4
        words, texts = [], []
        pc = base
        for it in self.items:
            if it[0] == "label":
                texts.append((None, None, it[1] + ":"))
                continue
            fn = it[1]
            try:
                w = fn(labels)
            except TypeError:
                w = fn(labels, pc)
            words.append(w)
            texts.append((pc, w, "    " + it[2]))
            pc += 4
        return words, texts, labels


TEST_DESCRIPTIONS = {
    "random_stress": "Randomized DIV/MULT stress test.",
}


def emit(outdir, name, prog, data_words, data_comments):
    os.makedirs(outdir, exist_ok=True)
    words, texts, _ = prog.assemble()
    code_end = START_PC + 4 * len(words)
    assert code_end <= DATA_BASE, f"code overruns data region: end=0x{code_end:x}"

    # .mem : one 32-bit hex word per line, line i == byte address 4*i
    mem = ["00000000"] * (DATA_BASE // 4 + len(data_words))
    for i, w in enumerate(words):
        mem[START_PC // 4 + i] = f"{w:08X}"
    for i, w in enumerate(data_words):
        mem[DATA_BASE // 4 + i] = f"{w:08X}"
    with open(os.path.join(outdir, name + ".mem"), "w") as f:
        f.write("\n".join(mem) + "\n")

    desc = TEST_DESCRIPTIONS.get(name, f"{name} ALU test.")

    # .lst : human-readable listing
    with open(os.path.join(outdir, name + ".lst"), "w") as f:
        f.write(f"# {name} listing\n")
        f.write("#-----------------------------------------------------------------------------\n")
        f.write("#\n")
        f.write(f"# {desc}\n")
        f.write(f"# code @ 0x{START_PC:x}, data @ 0x{DATA_BASE:x}\n")
        f.write("#\n\n")
        for pc, w, t in texts:
            if pc is None:
                f.write(f"{t}\n")
            else:
                f.write(f"  {pc:08x}: {w:08x}  {t}\n")
        f.write("\n# data\n")
        for i, w in enumerate(data_words):
            c = data_comments[i] if i < len(data_comments) else ""
            f.write(f"  {DATA_BASE + 4*i:08x}: {w:08x}  # {c}\n")

    # .S : rebuildable GNU as source (plain, no riscv_test.h dependency)
    with open(os.path.join(outdir, name + ".S"), "w") as f:
        f.write("#*****************************************************************************\n")
        f.write(f"# {name}.S\n")
        f.write("#-----------------------------------------------------------------------------\n")
        f.write("#\n")
        f.write(f"# {desc}\n")
        f.write("#\n")
        f.write(".section .text\n.globl _start\n_start:\n")
        for pc, w, t in texts:
            f.write(t + "\n")
        f.write(f"\n.section .data\n.org 0x{DATA_BASE - 0x390:x}  # data placed at 0x{DATA_BASE:x} via link.ld\n")
        for i, w in enumerate(data_words):
            c = data_comments[i] if i < len(data_comments) else ""
            f.write(f"    .word 0x{w:08x}  # {c}\n")


def init_regs(p):
    for r in range(1, 32):
        p.li(r, 0)


# ------------------------------------------- shared streamed-op test builder

def build_ops_test(name, ops, outdir, reuse_aluop=False, gap=0):
    """Emit a streamed-op ALU test from a list of ops.

    ops: list of (aluop, op1_hex, op2_hex, expected_hex, comment).
    reuse_aluop: if True, only (re)load ALUOP when it differs from the previous
                 op. Consecutive same-type ops then stream operand pairs WITHOUT
                 reloading ALUOP.
    gap: NOPs inserted between ops (0 = maximum pressure).

    Data layout: one 4-word block per op = [ALUOP, OP1, OP2, result slot].
    A single base pointer (x5) addresses every block via a 12-bit offset.
    """
    data, dcom = [], []
    for aluop, a, b, exp, com in ops:
        data += [aluop, a, b, 0]
        dcom += [f"ALUOP ({com})", "OP1", "OP2", "result slot"]

    p = Prog()
    init_regs(p)
    p.li(5, DATA_BASE, "x5 = data block base")
    p.li(3, 2, "gp=2: hang before/inside burst means a deadlock")

    # zero-gap (or gap-spaced) burst
    p.label("burst")
    prev_aluop = None
    for i, (aluop, a, b, exp, com) in enumerate(ops):
        off = 16 * i
        if (not reuse_aluop) or (aluop != prev_aluop):
            p.lw_(29, 5, off + 0, f"op{i}: load ALUOP")
            prev_aluop = aluop
        p.lw_(30, 5, off + 4, f"op{i}: load OP1")
        p.lw_(31, 5, off + 8, f"op{i}: load OP2")
        p.sw_(27, 5, off + 12, f"op{i}: store result ({com})")
        if gap:
            p.nop(gap)

    # verify each result; gp holds the failing op index on mismatch
    for i, (aluop, a, b, exp, com) in enumerate(ops):
        p.li(3, 3 + i, f"check op{i}")
        p.lw_(21, 5, 16 * i + 12, "read back result")
        p.li(22, exp, f"expected {com}")
        p.bne_(21, 22, "fail")

    p.label("pass")
    p.li(3, 1)
    p.nop(4)
    p.j_("theend")
    p.label("fail")
    p.nop(4)
    p.j_("theend")
    p.label("theend")
    p.nop(4)

    emit(outdir, name, p, data, dcom)


# =============================================================================
# TODO (take-home): implement YOUR randomized stress test below.
# =============================================================================
# You only fill in the two functions. Do NOT rewrite build_ops_test / Prog / emit.
# Flow: pick exact float32 operands → build a list of ops → call build_ops_test
# → files land in test/student/ → ./run_tests.sh student
# Helper already provided above: f2h(x) turns a Python float/int into IEEE-754
# float32 bits (the hex form OP1/OP2/expected need).
# More background: test/tools/README.md

def rand_exact_op(rng):
    """Return one random (aluop, op1_hex, op2_hex, expected_hex, comment).

    TODO (take-home) suggestions:
      1. Flip a coin with rng (e.g. rng.random()) to choose DIV (aluop=1) or
         MULT (aluop=2).
      2. MULT path: pick two small positive integers (keep the product well
         below 2^24 so float32 can represent it exactly). Convert both factors
         and the product with f2h(...). expected is the product.
      3. DIV path: pick a quotient q and a divisor d (small positives). Set the
         dividend to q*d. Then OP1=f2h(dividend), OP2=f2h(d), expected=f2h(q)
         so the division reads back exactly as q.
      4. Return a 5-tuple: (aluop, op1_bits, op2_bits, expected_bits, short_comment).
         The comment is only for the .lst listing; human-readable is fine.
      5. Avoid 0 divisors; stick to positive ints so you do not fight NaN/Inf here.

    Why this shape? The checker embeds expected_hex and compares the ALU's OP3
    store against it. If your floats are not exact, a correct HDL can still "fail".
    """
    raise NotImplementedError("TODO: implement rand_exact_op")



def gen_random_stress(outdir, seed=3220, n_ops=10):
    """Build n_ops random ops and emit test/student/random_stress.{mem,S,lst}.

    TODO (take-home) suggestions:
      1. Make an RNG from the seed: random.Random(seed) so the same seed always
         rebuilds the same test (required for a personalized, reproducible submit).
      2. Call rand_exact_op(rng) in a loop n_ops times; collect the tuples in a list.
      3. Hand that list to build_ops_test(...). Use name "random_stress" and this
         outdir so files land in test/student/.
      4. For a first working version, call build_ops_test with reuse_aluop=False
         and gap=0 (ALUOP reloaded every op, this is easier while debugging HDL).
         Once stalls + handshake work, try reuse_aluop=True to stress streaming
         (same-type ops without reloading ALUOP; needs the bonus-style ack).
      5. Return the ops list (the __main__ block prints how many you generated).

    You do not write assembly yourself (that would be awful); build_ops_test turns the op list into
    the LW/SW mailbox program and the self-check against expected_hex.
    """
    raise NotImplementedError("TODO: implement gen_random_stress")



if __name__ == "__main__":
    ap = argparse.ArgumentParser(
        description="Lab 3 test generator (take-home random test)")
    ap.add_argument("--seed", type=int, default=3220,
                    help="RNG seed for YOUR randomized test (use a personal value)")
    ap.add_argument("--n-ops", type=int, default=10,
                    help="number of ops in your randomized test")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    student = os.path.join(here, "..", "student")

    ops = gen_random_stress(student, seed=args.seed, n_ops=args.n_ops)
    print(f"generated: test/student/random_stress.{{mem,S,lst}} "
          f"(seed={args.seed}, n_ops={args.n_ops}, {len(ops)} ops)")
    print("run with:  ./run_tests.sh student")

# CS3220 Lab #4 : On-chip Communication Protocols

Autograded on Gradescope: Part 1 (40 pts) + Part 2 (60 pts) + Bonus (10 pts) = 110 pts, rescaled into 15% of your final score of the course.  

**Part 1: AXI-Stream FIFO**: 40 pts

**Part 2: AXI4 RAM**: 60 pts

**Bonus**: 10 pts

***Submission ddl***: November 6th, 2026

In this lab, you will delve into the robust and scalable on-chip communication protocol, AXI4, along with its streaming variant, AXI-Stream. The objective is to design and implement FIFOs/RAMs that leverage these two protocols for content reading and writing. While the previous lab focused on a straightforward register-based communication protocol for data exchange between the CPU and ALU, it lacked the scalability and robustness required for intricate communication scenarios. Such scenarios might involve more advanced modules, like a systolic array. Building on the knowledge gained in this assignment, the subsequent lab will guide you in utilizing the FIFOs/RAMs you've crafted to interconnect components within a sophisticated heterogeneous system.

## Part 1: AXI-Stream FIFO: 

In this section, you'll finish the implementation of an AXI-Stream FIFO. Please also refer to the FAQ section for more design references.

For the FIFO part, there are two pointers corresponding to the read and write actions, respectively.
* Each time the FIFO is read, the read pointer will be incremented by 1.
* Each time the FIFO is written, the write pointer will be incremented by 1.
* The read and write pointers are intentionally defined one bit wider than the bits needed to represent the FIFO address. 
    * This is to avoid the ambiguous case for empty and full FIFOs.
    * Thus, when the FIFO is empty, the read pointer will be equal to the write pointer. When the FIFO is full, the 1st bit of the read and write pointers need to be different (They are in different wrap-around positions), while the rest of the bits are the same.
* For better robustness, the pointer binary code is converted to gray code: ptr = ptr ^ (ptr >> 1).
    * The full and empty case will be conditioned on the gray code instead.
    * Note: Following the above logic, you need to come up with new logic to decide the full and empty case.

The code skeleton is provided in [axis_data_fifo.v](axis_data_fifo.v). Finish all the TODOs in the code.

To test your implementation, run the following command:

```make axis_data_fifo```

The test script is based on the testbench provided in [tb_axis_fifo.v](tb_axis_fifo.v).







## Part 2: AXI4 RAM (60 points)
AXI-stream can only support accesses with a set of regular and consecutive addresses, which is limited in many applications. 
To support more general accesses, we need to use AXI4 protocol.
In this section, you'll finish the implementation of an AXI4 RAM. Please also refer to the FAQ section for more design references.
Mostly, you will deal with managing the ready/valid signals and the transition among different read/write states. RAM interfaces have been handled for you.

The code skeleton is provided in [axi4_ram.v](axi4_ram.v). Finish all the TODOs in the code.

To test your implementation, run the following command:

```make axi4_ram```

The test script is based on the testbench provided in [tb_axi4_ram.v](tb_axi4_ram.v).


## Bonus: AXI4 RAM Burst Mode (10 points)
In this section, you'll modify the implementation of an AXI4 RAM to supports burst mode. We provide a new code skeleton in [axi4_ram_burst.v](axi4_ram_burst.v). Please combine with your previous parts implementation to finish all the TODOs in the code. You code should still pass the previous tests on non-burst mode.


Here are also some useful links for you:
+ https://www.youtube.com/watch?v=ydSy7uO60Is
+ https://www.youtube.com/watch?v=_twa6kY-ors 
+ https://www.youtube.com/watch?v=ZDNOezaQ4Fk 
+ https://www.youtube.com/watch?v=lI5Gh-1zk-s 

To test your implementation, run the following commands:

```make axi4_ram_burst``` (sweep + directed burst tests, 8 pts)

```make axi4_ram_burst_on_non_burst``` (2 pts)

## How Part 2 and the Bonus are graded

Gradescope runs exactly the `make` targets below, and awards points per test:

| Make target | Tests | Points |
|---|---|---|
| `axi4_ram_complete_transaction` | HLS sweep | 22 |
| `axi4_ram_tests` | E1–E3, E6, E8–E16 (13 edge tests) | 26 (2 each) |
| `axi4_ram_tests` | CORNER 1–3 | 12 (4 each) |
| `axi4_ram_burst_sweep` (Bonus) | HLS burst sweep | 2 |
| `axi4_ram_burst_on_non_burst` (Bonus) | burst RTL on non-burst tester | 2 |
| `axi4_ram_burst_tests` (Bonus) | BE1–BE8 | 2 (0.25 each) |
| `axi4_ram_burst_tests` (Bonus) | BURST 1–10 | 4 (0.4 each) |

Every test the benches print is graded, so what you see locally is what Gradescope scores.

## Additional Tests

`make axi4_ram` and `make axi4_ram_burst` each run two benches: the HLS round-trip sweep, followed by a combined directed bench of edge and protocol-corner cases. Each directed test prints PASS/FAIL, so you can see which scenario breaks. A correct implementation passes every test in these benches. You can also run the parts separately:

| Target | Testbench | What it covers |
|--------|-----------|----------------|
| `make axi4_ram_complete_transaction` | [tb_axi4_ram.v](tb_axi4_ram.v) | HLS single-beat write/read/compare sweep |
| `make axi4_ram_tests` | [tb_axi4_ram_tests.v](tb_axi4_ram_tests.v) | Non-burst edge + protocol-corner cases |
| `make axi4_ram_burst_sweep` | [tb_axi4_ram_burst.v](tb_axi4_ram_burst.v) | HLS burst write/read/compare sweep |
| `make axi4_ram_burst_tests` | [tb_axi4_ram_burst_tests.v](tb_axi4_ram_burst_tests.v) | Burst edge + protocol-corner cases |

The burst targets build [axi4_ram_burst.v](axi4_ram_burst.v); the others build [axi4_ram.v](axi4_ram.v).

## Submission

+ Provide a zip file containing your source code. Generate the submission.zip file using the command `make submit`. Avoid manual zip file creation to prevent any issues with the autograding script.



## FAQ 
[Q] Useful links to refer to for AXI4 design?\
[A] Official AXI4 specification: [link1](https://developer.arm.com/documentation/ihi0022/g/) [link2](https://documentation-service.arm.com/static/642583d7314e245d086bc8c9?token=); 

Handy timing diagrams from Xilinx: [link3](https://docs.google.com/presentation/d/1fUulgpJMmuZ_iGeoqGIIaTosDAveB6BM/edit?usp=sharing&ouid=103731133449796992574&rtpof=true&sd=true); 

Another set of diagrams from Oakland University: [link4](https://www.secs.oakland.edu/~llamocca/Courses/ECE495/Notes%20-%20Unit%205.pdf) 



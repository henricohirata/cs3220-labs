`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps

module majority3 (
    input x,
    input y,
    input z,
    output vote
);

    assign vote = (x & y) | (y & z) | (x & z);

endmodule
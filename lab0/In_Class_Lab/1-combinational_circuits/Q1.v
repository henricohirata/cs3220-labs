`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps

module combinational_circuits (
    input p1a, p1b, p1c, p1d, p1e, p1f,
    input p2a, p2b, p2c, p2d,
    output p1y,
    output p2y 
);

    assign p1y = (p1a & p1b & p1c) | (p1d & p1e & p1f);
    assign p2y = (p2a & p2b) | (p2c & p2d);

endmodule
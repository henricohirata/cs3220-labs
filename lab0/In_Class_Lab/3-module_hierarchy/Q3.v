`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps

module module_hierarchy ( 
    input [31:0] a,
    input [31:0] b,
    output [31:0] sum
);

    wire c0, c1;
    wire [15:0] sum0, sum1;

    add16 a16_0 (.a(a[15:0]), .b(b[15:0]), .cin(0), .sum(sum0), .cout(c0));
    add16 a16_1 (.a(a[31:16]), .b(b[31:16]), .cin(c0), .sum(sum1), .cout(c1));

    assign sum[31:16] = sum1;
    assign sum[15:0]  = sum0;

endmodule

module add1 ( input a, input b, input cin,   output sum, output cout );

    assign sum = ((a ^ b) ^ cin);
    assign cout = (((a ^ b)) & cin) | (a & b);

endmodule
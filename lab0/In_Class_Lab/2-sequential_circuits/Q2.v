`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps

module sequential_circuits ( 
    input clk,    // Clocks are used in sequential circuits
    input d,
    output q );

    reg q_reg;

    always @(posedge clk) begin
        q_reg <= d;
    end
    
    assign q = q_reg;

endmodule
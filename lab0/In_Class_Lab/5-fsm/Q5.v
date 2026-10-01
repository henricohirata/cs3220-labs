`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps

module fsm ( 
    input clk,    // Clocks are used in sequential circuits
    input reset,
    input seq,
    output detected 
); // seq detector 1101, once detected, output 1 for 1 clock cycle

    localparam [2:0]
        S0 = 3'd000,
        S1 = 3'd001,
        S2 = 3'd010,
        S3 = 3'd011,
        S4 = 3'd100;

    reg [2:0] state, next_state;

    always @(posedge clk) begin

        if (reset) begin
            state <= S0;
        end else begin
            state <= next_state;
        end
        
    end

    always @(*) begin
        case (state)
            S0: next_state = (seq) ? S1 : S0;
            S1: next_state = (seq) ? S2 : S0;
            S2: next_state = (seq) ? S2 : S3;
            S3: next_state = (seq) ? S4 : S0;
            S4: next_state = (seq) ? S2 : S0;
            default: next_state = S0;
        endcase
    end

    assign detected = (state == S4) ? 1 : 0;
    
endmodule
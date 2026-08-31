`timescale 1ns/1ps

module c5_bram_controller #(
    parameter path = "E:/Downloads/lenet_5_acc"
    ) (
    input clk,
    input rst_n,
    input i_line_buffer_valid,     // request
    output wire [599:0] o_ch_weight
);
    
    localparam ADDR_WIDTH = 10;

    reg  [ADDR_WIDTH-1:0] bram_addr_reg;
    wire [599:0]          bram_dout;

    // Address update & reset logic
    // - Increment while i_line_buffer_valid is HIGH (one word per cycle).
    // - Reset to 0 when not streaming or on reset.
    always @(posedge clk) begin
        if (!rst_n) begin
            bram_addr_reg <= 0;
        end else if (i_line_buffer_valid) begin
            bram_addr_reg <= bram_addr_reg + 1;
        end else begin
            bram_addr_reg <= 0;
        end
    end

    // BRAM instance
    single_port_bram #(
        .RAM_WIDTH(600),
        .RAM_DEPTH(640),
        .RAM_PERFORMANCE("LOW_LATENCY"),
        .INIT_FILE({path,"/weights/c5_weights_final_ordered.hex"}) 
    ) bram_inst (
        .clka   (clk),
        .ena    (1'b1),
        .wea    (1'b0),
        .addra  (bram_addr_reg),
        .dina   (600'd0),
        .rst_n  (rst_n),
        .regcea (1'b1),
        .douta  (bram_dout)
    );

    assign o_ch_weight = bram_dout;

endmodule

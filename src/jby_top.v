`timescale 1ns/1ps

// Top-level wrapper connecting c5_conv and c5_bram_controller
module jby_top #(
    parameter path = "E:/Downloads/lenet_5_acc"
    ) (
    input clk,
    input rst_n,

    // Feature map input
    input c3_mp_out_valid,
    input [7:0] c3_mp_out_ch_0,  input [7:0] c3_mp_out_ch_1,  input [7:0] c3_mp_out_ch_2,
    input [7:0] c3_mp_out_ch_3,  input [7:0] c3_mp_out_ch_4,  input [7:0] c3_mp_out_ch_5,
    input [7:0] c3_mp_out_ch_6,  input [7:0] c3_mp_out_ch_7,  input [7:0] c3_mp_out_ch_8,
    input [7:0] c3_mp_out_ch_9,  input [7:0] c3_mp_out_ch_10, input [7:0] c3_mp_out_ch_11,
    input [7:0] c3_mp_out_ch_12, input [7:0] c3_mp_out_ch_13, input [7:0] c3_mp_out_ch_14,
    input [7:0] c3_mp_out_ch_15,

    // Final outputs
    output o_c5_valid,
    output [23:0] o_c5_conv_pu
);

    wire [599:0] w_ch_weight;
    wire         w_line_buffer_valid;

    // BRAM controller
    c5_bram_controller #(
        .path(path)
    ) bram_ctrl_inst (
        .clk                 (clk),
        .rst_n               (rst_n),
        .i_line_buffer_valid (w_line_buffer_valid), // consume request from c5_conv
        .o_ch_weight         (w_ch_weight)          // provide weight data to c5_conv
    );

    // c5_conv DUT
    c5_conv c5_conv_inst (
        .clk              (clk),
        .rst_n            (rst_n),
        .c3_mp_out_valid  (c3_mp_out_valid),
        .c3_mp_out_ch_0   (c3_mp_out_ch_0),  .c3_mp_out_ch_1 (c3_mp_out_ch_1),  .c3_mp_out_ch_2 (c3_mp_out_ch_2),
        .c3_mp_out_ch_3   (c3_mp_out_ch_3),  .c3_mp_out_ch_4 (c3_mp_out_ch_4),  .c3_mp_out_ch_5 (c3_mp_out_ch_5),
        .c3_mp_out_ch_6   (c3_mp_out_ch_6),  .c3_mp_out_ch_7 (c3_mp_out_ch_7),  .c3_mp_out_ch_8 (c3_mp_out_ch_8),
        .c3_mp_out_ch_9   (c3_mp_out_ch_9),  .c3_mp_out_ch_10(c3_mp_out_ch_10), .c3_mp_out_ch_11(c3_mp_out_ch_11),
        .c3_mp_out_ch_12  (c3_mp_out_ch_12), .c3_mp_out_ch_13(c3_mp_out_ch_13), .c3_mp_out_ch_14(c3_mp_out_ch_14),
        .c3_mp_out_ch_15  (c3_mp_out_ch_15),

        .i_ch_weight      (w_ch_weight),          // weights from controller
        
        .line_buffer_valid(w_line_buffer_valid),  // request signal to controller
        .o_c5_valid       (o_c5_valid),
        .o_c5_conv_pu     (o_c5_conv_pu)
    );

endmodule

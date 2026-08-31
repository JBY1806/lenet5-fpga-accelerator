`timescale 1ns/1ps

module c5_conv(
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
    
    // Weight input
    input [599:0] i_ch_weight,
    
    // Control & final results
    output line_buffer_valid, // interface with c5_bram_controller (weight request)
    output reg o_c5_valid,
    output reg [23:0] o_c5_conv_pu
);

    // --- FSM state encoding ---
    localparam S_IDLE        = 2'b00;
    localparam S_COLLECTING  = 2'b01;
    localparam S_COMPUTING   = 2'b11;
    
    reg [1:0] state, next_state;

    // --- Internal registers & counters ---
    reg [39:0] s4_ch_buffer[0:15][0:4];
    reg [4:0] pixel_count;
    reg [3:0] p_ch_cnt;
    reg [5:0] compute_cnt;

    // --- Pipeline registers ---
    (* use_dsp = "yes" *) reg signed [16:0] p1_products_0[0:24], p1_products_1[0:24], p1_products_2[0:24];
    reg p1_valid;
    reg [3:0] p1_ch_cnt;
    
    reg signed [19:0] p2_partial_sums_0[0:4], p2_partial_sums_1[0:4], p2_partial_sums_2[0:4];
    reg p2_valid;
    reg [3:0] p2_ch_cnt;

    reg signed [22:0] p3_ch_sum_0, p3_ch_sum_1, p3_ch_sum_2;
    reg p3_valid;
    reg [3:0] p3_ch_cnt;

    reg signed [31:0] p4_acc_0, p4_acc_1, p4_acc_2;
    reg p4_valid;
    reg [3:0] p4_ch_cnt;

    // =========================================================================
    // 1) State register update (sequential logic)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // =========================================================================
    // 2) Next-state logic (combinational)
    // =========================================================================
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (c3_mp_out_valid) begin
                    next_state = S_COLLECTING;
                end
            end
            S_COLLECTING: begin
                if (pixel_count == 5'd24 && c3_mp_out_valid) begin
                    next_state = S_COMPUTING;
                end
            end

            S_COMPUTING: begin
                if (p_ch_cnt == 4'd15) begin
                    if (compute_cnt == 6'd39) begin
                        next_state = S_IDLE;
                    end
                end
            end
        endcase
    end
    
    // =========================================================================
    // 3) Output & internal register logic (sequential & combinational)
    // =========================================================================
    
    // --- Combinational assigns ---
    wire [127:0] c3_mp_out_bus;
    wire signed [31:0] w_relu_out_0, w_relu_out_1, w_relu_out_2;
    wire [7:0] w_quan_out_0, w_quan_out_1, w_quan_out_2;
    wire w_is_output_cycle;
    wire signed [199:0] w_weight_0, w_weight_1, w_weight_2;
    
    assign c3_mp_out_bus = {c3_mp_out_ch_15, c3_mp_out_ch_14, c3_mp_out_ch_13, c3_mp_out_ch_12,
                            c3_mp_out_ch_11, c3_mp_out_ch_10, c3_mp_out_ch_9,  c3_mp_out_ch_8,
                            c3_mp_out_ch_7,  c3_mp_out_ch_6,  c3_mp_out_ch_5,  c3_mp_out_ch_4,
                            c3_mp_out_ch_3,  c3_mp_out_ch_2,  c3_mp_out_ch_1,  c3_mp_out_ch_0};
    assign w_weight_0 = i_ch_weight[199:0];
    assign w_weight_1 = i_ch_weight[399:200];
    assign w_weight_2 = i_ch_weight[599:400];

    // ReLU activation
    assign w_relu_out_0 = (p4_acc_0[31]) ? 32'sd0 : p4_acc_0;
    assign w_relu_out_1 = (p4_acc_1[31]) ? 32'sd0 : p4_acc_1;
    assign w_relu_out_2 = (p4_acc_2[31]) ? 32'sd0 : p4_acc_2;

    // Quantization (saturate to 8-bit, with rounding)
    assign w_quan_out_0 = (|w_relu_out_0[31:15]) ? 8'd255
                          : ((&w_relu_out_0[14:7]) ? w_relu_out_0[14:7]
                          :  (w_relu_out_0[14:7] + w_relu_out_0[6]));
    assign w_quan_out_1 = (|w_relu_out_1[31:15]) ? 8'd255
                          : ((&w_relu_out_1[14:7]) ? w_relu_out_1[14:7]
                          :  (w_relu_out_1[14:7] + w_relu_out_1[6]));
    assign w_quan_out_2 = (|w_relu_out_2[31:15]) ? 8'd255
                          : ((&w_relu_out_2[14:7]) ? w_relu_out_2[14:7]
                          :  (w_relu_out_2[14:7] + w_relu_out_2[6]));

    // Output when the last channel in the block completes
    assign w_is_output_cycle = p4_valid && (p4_ch_cnt == 4'd15);

    // Assert line_buffer_valid while finishing collection and throughout COMPUTING
    assign line_buffer_valid =
           (state == S_COLLECTING && pixel_count == 5'd24 && c3_mp_out_valid) ||
           (state == S_COMPUTING && compute_cnt != 6'd40); // keep requesting weights in c5_bram_controller

    // --- Remaining sequential logic (counters, pipeline regs, etc.) ---
    integer ch_idx, i, px;
    always @(posedge clk) begin
        if (!rst_n) begin
            pixel_count <= 5'd0;
            p_ch_cnt    <= 4'd0;
            compute_cnt <= 6'd0;
            o_c5_valid  <= 1'b0;
            o_c5_conv_pu<= 24'd0;

            p1_valid <= 1'b0; p2_valid <= 1'b0; p3_valid <= 1'b0; p4_valid <= 1'b0;
            p1_ch_cnt <= 4'd0; p2_ch_cnt <= 4'd0; p3_ch_cnt <= 4'd0; p4_ch_cnt <= 4'd0;

            p3_ch_sum_0 <= 23'sd0; p3_ch_sum_1 <= 23'sd0; p3_ch_sum_2 <= 23'sd0;
            p4_acc_0 <= 32'sd0;    p4_acc_1 <= 32'sd0;    p4_acc_2 <= 32'sd0;

            for (ch_idx = 0; ch_idx < 16; ch_idx = ch_idx + 1)
                for (i = 0; i < 5; i = i + 1)
                    s4_ch_buffer[ch_idx][i] <= 40'd0;

            for (px = 0; px < 25; px = px + 1) begin
                p1_products_0[px] <= 0; p1_products_1[px] <= 0; p1_products_2[px] <= 0;
            end
            for (i = 0; i < 5; i = i + 1) begin
                p2_partial_sums_0[i] <= 0; p2_partial_sums_1[i] <= 0; p2_partial_sums_2[i] <= 0;
            end
        end else begin
            // --- Counters & input line-buffer updates ---
            case(state)
                S_IDLE: begin
                    if (c3_mp_out_valid) begin
                        for (ch_idx = 0; ch_idx < 16; ch_idx = ch_idx + 1) begin
                            s4_ch_buffer[ch_idx][pixel_count/5][(pixel_count%5)*8 +: 8]
                                <= c3_mp_out_bus[ch_idx*8 +: 8];
                        end
                        pixel_count <= pixel_count + 1;
                    end
                end
                S_COLLECTING: begin
                    if (c3_mp_out_valid) begin
                        pixel_count <= pixel_count + 1;
                        for (ch_idx = 0; ch_idx < 16; ch_idx = ch_idx + 1) begin
                            s4_ch_buffer[ch_idx][pixel_count/5][(pixel_count%5)*8 +: 8]
                                <= c3_mp_out_bus[ch_idx*8 +: 8];
                        end
                        if (pixel_count == 5'd24) begin
                            compute_cnt <= 6'd0;
                        end
                    end
                end
                S_COMPUTING: begin
                    p_ch_cnt <= p_ch_cnt + 1;
                    if (p_ch_cnt == 4'd15) begin
                        compute_cnt <= compute_cnt + 1;
                    end
                end
            endcase

            // Reset channel counter when entering COMPUTING
            if (state == S_COLLECTING && next_state == S_COMPUTING) begin
                p_ch_cnt <= 4'd0;
            end

            // Reset pixel counter when returning to IDLE
            if (state == S_COMPUTING && next_state == S_IDLE) begin
                pixel_count <= 5'd0;
            end
            
            // --- Pipeline stage updates ---
            p1_valid <= (state == S_COMPUTING);
            if (state == S_COMPUTING || next_state == S_COMPUTING) begin
                p1_ch_cnt <= p_ch_cnt;
                for (px = 0; px < 25; px = px + 1) begin
                    p1_products_0[px] <= $signed({1'b0, s4_ch_buffer[p_ch_cnt][px/5][(px%5)*8 +: 8]})
                                       * $signed(w_weight_0[px*8 +: 8]);
                    p1_products_1[px] <= $signed({1'b0, s4_ch_buffer[p_ch_cnt][px/5][(px%5)*8 +: 8]})
                                       * $signed(w_weight_1[px*8 +: 8]);
                    p1_products_2[px] <= $signed({1'b0, s4_ch_buffer[p_ch_cnt][px/5][(px%5)*8 +: 8]})
                                       * $signed(w_weight_2[px*8 +: 8]);
                end
            end

            p2_valid <= p1_valid;
            if (p1_valid) begin
                p2_ch_cnt <= p1_ch_cnt;
                for (i = 0; i < 5; i = i + 1) begin
                    p2_partial_sums_0[i] <= p1_products_0[i*5+0] + p1_products_0[i*5+1] + p1_products_0[i*5+2] + p1_products_0[i*5+3] + p1_products_0[i*5+4];
                    p2_partial_sums_1[i] <= p1_products_1[i*5+0] + p1_products_1[i*5+1] + p1_products_1[i*5+2] + p1_products_1[i*5+3] + p1_products_1[i*5+4];
                    p2_partial_sums_2[i] <= p1_products_2[i*5+0] + p1_products_2[i*5+1] + p1_products_2[i*5+2] + p1_products_2[i*5+3] + p1_products_2[i*5+4];
                end
            end

            p3_valid <= p2_valid;
            if (p2_valid) begin
                p3_ch_cnt  <= p2_ch_cnt;
                p3_ch_sum_0 <= p2_partial_sums_0[0] + p2_partial_sums_0[1] + p2_partial_sums_0[2] + p2_partial_sums_0[3] + p2_partial_sums_0[4];
                p3_ch_sum_1 <= p2_partial_sums_1[0] + p2_partial_sums_1[1] + p2_partial_sums_1[2] + p2_partial_sums_1[3] + p2_partial_sums_1[4];
                p3_ch_sum_2 <= p2_partial_sums_2[0] + p2_partial_sums_2[1] + p2_partial_sums_2[2] + p2_partial_sums_2[3] + p2_partial_sums_2[4];
            end
            
            p4_valid <= p3_valid;
            if (p3_valid) begin
                p4_ch_cnt <= p3_ch_cnt;
                if (p3_ch_cnt == 4'd0) begin
                    p4_acc_0 <= p3_ch_sum_0; p4_acc_1 <= p3_ch_sum_1; p4_acc_2 <= p3_ch_sum_2;
                end else begin
                    p4_acc_0 <= p4_acc_0 + p3_ch_sum_0;
                    p4_acc_1 <= p4_acc_1 + p3_ch_sum_1;
                    p4_acc_2 <= p4_acc_2 + p3_ch_sum_2;
                end
            end
            
            // --- Final output update ---
            o_c5_valid <= w_is_output_cycle;
            if (w_is_output_cycle) begin
                o_c5_conv_pu <= {w_quan_out_2, w_quan_out_1, w_quan_out_0};
            end
        end
    end
endmodule

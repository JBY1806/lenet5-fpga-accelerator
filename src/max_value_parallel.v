`timescale 1ns/1ps

module max_value_parallel (
    input  clk,
    input  rst_n,
    input  signed [319:0] o_g7_out,      // {val9, val8, ..., val0}
    input                 o_g7_out_valid,

    output reg [3:0]  o_max_idx,         // index of the maximum value
    output reg        o_max_val_valid,   // valid flag for max value
    output reg [31:0] o_logit_0,
    output reg [31:0] o_logit_1,
    output reg [31:0] o_logit_2,
    output reg [31:0] o_logit_3,
    output reg [31:0] o_logit_4,
    output reg [31:0] o_logit_5,
    output reg [31:0] o_logit_6,
    output reg [31:0] o_logit_7,
    output reg [31:0] o_logit_8,
    output reg [31:0] o_logit_9
);

    // Capture all 10 logits at once (kept as a single bundle)
    reg [319:0] r_logits;

    // Packed data for the comparison tree: {idx[3:0], val[31:0]} = 36 bits
    reg [35:0] r_vals       [0:9];  // 10 inputs
    reg [35:0] r_stage1_out [0:4];  // 10 → 5
    reg [35:0] r_stage2_out [0:2];  // 5  → 3
    reg [35:0] r_stage3_out [0:1];  // 3  → 2
    reg [35:0] r_stage4_out;        // 2  → 1 (final winner)

    // Pipeline valid flags
    reg v_capt, v_s1, v_s2, v_s3, v_s4;

    // Input capture and comparison pipeline
    always @(posedge clk) begin
        if (!rst_n) begin
            r_logits <= {320{1'b0}};
            v_capt <= 1'b0; v_s1 <= 1'b0; v_s2 <= 1'b0; v_s3 <= 1'b0; v_s4 <= 1'b0;
        end else begin
            // Stage 0: capture inputs
            v_capt <= o_g7_out_valid;
            if (o_g7_out_valid) begin
                r_logits <= o_g7_out;

                r_vals[0] <= {4'd0, o_g7_out[ 31:  0]};
                r_vals[1] <= {4'd1, o_g7_out[ 63: 32]};
                r_vals[2] <= {4'd2, o_g7_out[ 95: 64]};
                r_vals[3] <= {4'd3, o_g7_out[127: 96]};
                r_vals[4] <= {4'd4, o_g7_out[159:128]};
                r_vals[5] <= {4'd5, o_g7_out[191:160]};
                r_vals[6] <= {4'd6, o_g7_out[223:192]};
                r_vals[7] <= {4'd7, o_g7_out[255:224]};
                r_vals[8] <= {4'd8, o_g7_out[287:256]};
                r_vals[9] <= {4'd9, o_g7_out[319:288]};
            end

            // Stage 1: 10 → 5
            v_s1 <= v_capt;
            if (v_capt) begin
                r_stage1_out[0] <= ($signed(r_vals[0][31:0]) >= $signed(r_vals[1][31:0])) ? r_vals[0] : r_vals[1];
                r_stage1_out[1] <= ($signed(r_vals[2][31:0]) >= $signed(r_vals[3][31:0])) ? r_vals[2] : r_vals[3];
                r_stage1_out[2] <= ($signed(r_vals[4][31:0]) >= $signed(r_vals[5][31:0])) ? r_vals[4] : r_vals[5];
                r_stage1_out[3] <= ($signed(r_vals[6][31:0]) >= $signed(r_vals[7][31:0])) ? r_vals[6] : r_vals[7];
                r_stage1_out[4] <= ($signed(r_vals[8][31:0]) >= $signed(r_vals[9][31:0])) ? r_vals[8] : r_vals[9];
            end

            // Stage 2: 5 → 3
            v_s2 <= v_s1;
            if (v_s1) begin
                r_stage2_out[0] <= ($signed(r_stage1_out[0][31:0]) >= $signed(r_stage1_out[1][31:0])) ? r_stage1_out[0] : r_stage1_out[1];
                r_stage2_out[1] <= ($signed(r_stage1_out[2][31:0]) >= $signed(r_stage1_out[3][31:0])) ? r_stage1_out[2] : r_stage1_out[3];
                r_stage2_out[2] <= r_stage1_out[4];
            end

            // Stage 3: 3 → 2
            v_s3 <= v_s2;
            if (v_s2) begin
                r_stage3_out[0] <= ($signed(r_stage2_out[0][31:0]) >= $signed(r_stage2_out[1][31:0])) ? r_stage2_out[0] : r_stage2_out[1];
                r_stage3_out[1] <= r_stage2_out[2];
            end

            // Stage 4: 2 → 1
            v_s4 <= v_s3;
            if (v_s3) begin
                r_stage4_out <= ($signed(r_stage3_out[0][31:0]) >= $signed(r_stage3_out[1][31:0])) ? r_stage3_out[0] : r_stage3_out[1];
            end
        end
    end

    // Final outputs
    always @(posedge clk) begin
        if (!rst_n) begin
            o_max_idx <= 4'd0;
            o_max_val_valid <= 1'b0;
            {o_logit_0,o_logit_1,o_logit_2,o_logit_3,o_logit_4,
             o_logit_5,o_logit_6,o_logit_7,o_logit_8,o_logit_9} <= {10{32'd0}};
        end else begin
            o_max_val_valid <= v_s4;
            if (v_s4) begin
                o_max_idx <= r_stage4_out[35:32];

                // Unpack r_logits
                o_logit_0 <= r_logits[ 31:  0];
                o_logit_1 <= r_logits[ 63: 32];
                o_logit_2 <= r_logits[ 95: 64];
                o_logit_3 <= r_logits[127: 96];
                o_logit_4 <= r_logits[159:128];
                o_logit_5 <= r_logits[191:160];
                o_logit_6 <= r_logits[223:192];
                o_logit_7 <= r_logits[255:224];
                o_logit_8 <= r_logits[287:256];
                o_logit_9 <= r_logits[319:288];
            end
        end
    end
endmodule

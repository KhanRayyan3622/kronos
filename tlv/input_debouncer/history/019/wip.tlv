\m5_TLV_version 1d: tl-x.org
\m5
use(m5-1.0)
\SV
// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Simple Input Debouncer for groups of GPIO
*/

module input_debouncer #(
    parameter N = 16,
    parameter DEBOUNCE = 16
)(
    input  logic        clk,
    input  logic        rstz,
    output logic [N-1:0] read,
    input  logic [N-1:0] gpio_in
);
\TLV
   |default
      @0
         \SV_plus
            logic [DEBOUNCE : 0] timer;
            logic tick;

            // Synchronize the asynchronous, negatively-asserted reset input, asserting
            // asynchronously but deasserting synchronously to avoid recovery/removal
            // timing issues and metastability.
            logic resetn_meta, resetn;

            always_ff @(posedge clk or negedge rstz) begin
                if (~ rstz) begin
                    resetn_meta <= 1'b0;
                    resetn <= 1'b0;
                end else begin
                    resetn_meta <= 1'b1;
                    resetn <= resetn_meta;
                end
            end

            always_ff @(posedge clk) begin
                timer <=
                    ~ resetn ? '0 :
                    tick ? '0 :
                    timer + 1'b1;
            end

            assign tick = timer[DEBOUNCE];

            generate
                genvar i;

                for (i = 0; i < N; i++) begin
                    logic [1 : 0] sync;
                    logic raw_val;
                    logic [1 : 0] line;
                    logic [2 : 0] poll;

                    // sync inputs
                    always_ff @(posedge clk) begin
                        sync <= {sync[0], gpio_in[i]};
                    end

                    assign raw_val = sync[1];
                    assign poll = {line, raw_val};

                    // Record line value on every tick
                    // And if stable (three consecutive reads are the same), latch it
                    always_ff @(posedge clk) begin
                        line <= tick ? {line[0], raw_val} : line;

                        read[i] <=
                            tick ?
                                (poll == '0) ? 1'b0 :
                                (poll == '1) ? 1'b1 :
                                read[i] :
                            read[i];
                    end
                end
            endgenerate
\SV
endmodule

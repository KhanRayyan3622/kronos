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
         // Connect Verilog inputs:
         $gpio_in[N-1:0] = *gpio_in;

         \SV_plus
            // Synchronize the asynchronous, negatively-asserted reset input, asserting
            // asynchronously but deasserting synchronously to avoid recovery/removal
            // timing issues and metastability.
            always_ff @(posedge clk or negedge rstz) begin
                if (~ rstz) begin
                    $$resetn_meta <= 1'b0;
                    $$resetn <= 1'b0;
                end else begin
                    $resetn_meta <= 1'b1;
                    $resetn <= $resetn_meta;
                end
            end
         <<1$timer[DEBOUNCE : 0] = ~ $resetn ? '0 : $tick ? '0 : $timer + 1'b1;
         $tick = $timer[DEBOUNCE];
         /gpio[N-1:0]
            // sync inputs
            <<1$sync[1 : 0] = {$sync[0], |default$gpio_in[gpio]};
            $raw_val = $sync[1];
            $poll[2 : 0] = {$line, $raw_val};
            <<1$line[1 : 0] = |default$tick ? {$line[0], $raw_val} : $line;

            // Record line value on every tick
            // And if stable (three consecutive reads are the same), latch it
            <<1$read =
                |default$tick ?
                    ($poll == '0) ? 1'b0 :
                    ($poll == '1) ? 1'b1 :
                    $read :
                $read;

            // Connect Verilog outputs:
            *read[gpio] = $read;
\SV
endmodule

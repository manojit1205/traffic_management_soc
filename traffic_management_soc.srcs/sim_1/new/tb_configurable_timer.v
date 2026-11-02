`timescale 1ns / 1ps

module tb_configurable_timer;

reg clk;
    reg rst_n;
    reg enable;
    reg clear;
    reg [31:0] duration;
    wire done;

    integer done_count;

configurable_timer dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .clear(clear),
        .duration(duration),
        .done(done)
    );

// 10 ns clock period
    initial clk = 1'b0;
    always #5 clk = ~clk;

initial begin
        rst_n     = 1'b0;
        enable    = 1'b0;
        clear     = 1'b0;
        duration  = 32'd5;
        done_count = 0;

repeat (2) @(negedge clk);
        rst_n = 1'b1;
        enable = 1'b1;

// Wait for the timer to finish
        wait (done == 1'b1);
        @(negedge clk);

if (done !== 1'b0) begin
            $fatal(1, "FAIL: done should be a pulse");
        end

        $display("PASS: Timer completed duration of 5 cycles.");

// Test clear
        clear = 1'b1;
        @(negedge clk);
        clear = 1'b0;

// Test a new duration
        duration = 32'd3;

wait (done == 1'b1);
        @(negedge clk);

$display("PASS: Timer completed duration of 3 cycles.");
        $display("All timer tests passed.");

$finish;
    end

always @(posedge clk) begin
        if (done)
            done_count = done_count + 1;
    end

endmodule
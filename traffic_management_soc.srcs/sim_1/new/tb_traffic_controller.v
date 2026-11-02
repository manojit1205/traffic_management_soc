`timescale 1ns / 1ps

module tb_traffic_controller;

reg clk;
    reg rst_n;

wire ns_red;
    wire ns_yellow;
    wire ns_green;

wire ew_red;
    wire ew_yellow;
    wire ew_green;

// Short intervals for simulation
    traffic_controller #(
        .GREEN_CYCLES(5),
        .YELLOW_CYCLES(2),
        .ALL_RED_CYCLES(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

.ns_red(ns_red),
        .ns_yellow(ns_yellow),
        .ns_green(ns_green),

.ew_red(ew_red),
        .ew_yellow(ew_yellow),
        .ew_green(ew_green)
    );

// 10 ns clock period
    initial clk = 1'b0;
    always #5 clk = ~clk;

initial begin
        $timeformat(-9, 0, " ns", 8);

$display("======================================");
        $display(" Traffic Controller Simulation");
        $display("======================================");

$monitor(
            "T=%0t | NS RYG=%b%b%b | EW RYG=%b%b%b",
            $time,
            ns_red, ns_yellow, ns_green,
            ew_red, ew_yellow, ew_green
        );

// Apply reset
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

// Check the controller over multiple complete cycles
        repeat (40) begin
            @(negedge clk);

// Opposing traffic phases must never be green together
            if (ns_green && ew_green) begin
                $display("FAIL: Conflicting green signals!");
                $fatal(1);
            end

// Each direction must have exactly one active light
            if (({1'b0, ns_red} + {1'b0, ns_yellow}
                    + {1'b0, ns_green}) != 2'd1 ||
               ({1'b0, ew_red} + {1'b0, ew_yellow}
                    + {1'b0, ew_green}) != 2'd1) begin
               $display("FAIL: Invalid traffic-light output!");
               $fatal(1);
           end
        end

$display("PASS: No conflicting green signals.");
        $display("PASS: Traffic-light outputs are valid.");
        $display("======================================");

$finish;
    end

endmodule

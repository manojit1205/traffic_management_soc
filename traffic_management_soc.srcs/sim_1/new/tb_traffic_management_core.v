`timescale 1ns / 1ps

module tb_traffic_management_core;

    reg clk;
    reg rst_n;

    reg [1:0] ns_density;
    reg [1:0] ew_density;

    wire ns_red;
    wire ns_yellow;
    wire ns_green;

    wire ew_red;
    wire ew_yellow;
    wire ew_green;

    integer ns_green_cycles;
    integer ew_green_cycles;
    integer ns_green_phases;
    integer ew_green_phases;
    integer i;

    // Instantiate the adaptive traffic controller
    traffic_management_core #(
        .GREEN_LOW_CYCLES(3),
        .GREEN_MED_CYCLES(4),
        .GREEN_HIGH_CYCLES(5),
        .GREEN_VHIGH_CYCLES(6),
        .YELLOW_CYCLES(2),
        .ALL_RED_CYCLES(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .ns_density(ns_density),
        .ew_density(ew_density),

        .ns_red(ns_red),
        .ns_yellow(ns_yellow),
        .ns_green(ns_green),

        .ew_red(ew_red),
        .ew_yellow(ew_yellow),
        .ew_green(ew_green)
    );

    // Clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Check safety and measure green-phase lengths
    always @(posedge clk) begin
        if (rst_n) begin
            // Conflicting green signals must never occur
            if (ns_green && ew_green) begin
                $display("FAIL: Both directions are green!");
                $fatal(1);
            end

            // Exactly one light must be active per direction
            if (({1'b0, ns_red} +
                 {1'b0, ns_yellow} +
                 {1'b0, ns_green}) != 2'd1) begin
                $display("FAIL: Invalid North-South lights!");
                $fatal(1);
            end

            if (({1'b0, ew_red} +
                 {1'b0, ew_yellow} +
                 {1'b0, ew_green}) != 2'd1) begin
                $display("FAIL: Invalid East-West lights!");
                $fatal(1);
            end

            if (ns_green)
                ns_green_cycles = ns_green_cycles + 1;

            if (ew_green)
                ew_green_cycles = ew_green_cycles + 1;
        end
    end

    // Main stimulus
    initial begin
        rst_n = 1'b0;
        ns_density = 2'b00;
        ew_density = 2'b10;

        ns_green_cycles = 0;
        ew_green_cycles = 0;
        ns_green_phases = 0;
        ew_green_phases = 0;

        $display("========================================");
        $display(" Adaptive Traffic Controller Test");
        $display(" Vivado 2022.2");
        $display("========================================");

        // Reset
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // Test 1: NS low density -> 3 green cycles
        wait (dut.state == 3'd0);
        @(negedge clk);
        ns_green_cycles = 0;

        wait (dut.state == 3'd1);
        if (ns_green_cycles != 3)
            $fatal(1,
                "FAIL: NS low density expected 3 cycles, got %0d",
                ns_green_cycles);

        ns_green_phases = ns_green_phases + 1;
        $display("PASS: NS low-density green duration = 3 cycles");

        // Test 2: EW high density -> 5 green cycles
        wait (dut.state == 3'd3);
        @(negedge clk);
        ew_green_cycles = 0;

        wait (dut.state == 3'd4);
        if (ew_green_cycles != 5)
            $fatal(1,
                "FAIL: EW high density expected 5 cycles, got %0d",
                ew_green_cycles);

        ew_green_phases = ew_green_phases + 1;
        $display("PASS: EW high-density green duration = 5 cycles");

        // Set next NS density to very high.
        // This is sampled when the next NS green phase begins.
        ns_density = 2'b11;

        // Test 3: NS very high density -> 6 green cycles
        wait (dut.state == 3'd0);
        @(negedge clk);
        ns_green_cycles = 0;

        wait (dut.state == 3'd1);
        if (ns_green_cycles != 6)
            $fatal(1,
                "FAIL: NS very-high density expected 6 cycles, got %0d",
                ns_green_cycles);

        ns_green_phases = ns_green_phases + 1;
        $display("PASS: NS very-high-density green duration = 6 cycles");

        // Set next EW density to low.
        ew_density = 2'b00;

        // Test 4: EW low density -> 3 green cycles
        wait (dut.state == 3'd3);
        @(negedge clk);
        ew_green_cycles = 0;

        wait (dut.state == 3'd4);
        if (ew_green_cycles != 3)
            $fatal(1,
                "FAIL: EW low density expected 3 cycles, got %0d",
                ew_green_cycles);

        ew_green_phases = ew_green_phases + 1;
        $display("PASS: EW low-density green duration = 3 cycles");

        // Additional simulation for safety checks
        for (i = 0; i < 30; i = i + 1)
            @(negedge clk);

        $display("----------------------------------------");
        $display("PASS: No conflicting green signals");
        $display("PASS: Traffic-light outputs remain valid");
        $display("NS green phases checked: %0d", ns_green_phases);
        $display("EW green phases checked: %0d", ew_green_phases);
        $display("ALL TESTS PASSED");
        $display("========================================");

        $finish;
    end

    // Monitor state transitions
    always @(negedge clk) begin
        if (rst_n) begin
            $display(
                "Time=%0t | State=%0d | NS density=%b | EW density=%b | NS RYG=%b%b%b | EW RYG=%b%b%b",
                $time,
                dut.state,
                ns_density,
                ew_density,
                ns_red, ns_yellow, ns_green,
                ew_red, ew_yellow, ew_green
            );
        end
    end

    // Prevent a broken test from running indefinitely
    initial begin
        #10000;
        $fatal(1, "FAIL: Simulation timeout");
    end

endmodule
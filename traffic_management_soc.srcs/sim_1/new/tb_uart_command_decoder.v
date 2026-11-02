`timescale 1ns / 1ps

module tb_uart_command_decoder;

    reg clk;
    reg rst_n;

    reg [7:0] rx_data;
    reg rx_valid;
    reg tx_busy;

    wire [1:0] ns_density;
    wire [1:0] ew_density;

    wire [7:0] tx_data;
    wire tx_start;

    wire command_valid;
    wire command_error;

    integer tests_passed;

    // Instantiate UART command decoder
    uart_command_decoder dut (
        .clk(clk),
        .rst_n(rst_n),

        .rx_data(rx_data),
        .rx_valid(rx_valid),

        .ns_density(ns_density),
        .ew_density(ew_density),

        .tx_busy(tx_busy),
        .tx_data(tx_data),
        .tx_start(tx_start),

        .command_valid(command_valid),
        .command_error(command_error)
    );

    // Clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Send one command byte to the decoder
    task send_command;
        input [7:0] command;
        begin
            @(negedge clk);
            rx_data  = command;
            rx_valid = 1'b1;

            @(negedge clk);
            rx_valid = 1'b0;

            // Allow the decoder to process the command
            repeat (2) @(negedge clk);
        end
    endtask

    // Main test sequence
    initial begin
        rst_n = 1'b0;
        rx_data = 8'h00;
        rx_valid = 1'b0;
        tx_busy = 1'b0;
        tests_passed = 0;

        $display("======================================");
        $display(" UART COMMAND DECODER TEST");
        $display("======================================");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // ----------------------------------
        // TEST 1: NS density = HIGH
        // Command: 0x12
        // Expected density: 2'b10
        // Expected ACK: 0xA2
        // ----------------------------------
        send_command(8'h12);

        if (ns_density !== 2'b10)
            $fatal(1, "FAIL: NS density should be HIGH");

        if (command_valid !== 1'b0)
            $display("INFO: command_valid pulse has completed");

        wait (tx_start == 1'b1);
        #1;

        if (tx_data !== 8'hA2)
            $fatal(1, "FAIL: NS ACK expected A2, got %h", tx_data);

        $display("PASS: NS density HIGH, ACK = 0x%02h", tx_data);
        tests_passed = tests_passed + 1;

        @(negedge clk);

        // ----------------------------------
        // TEST 2: EW density = VERY HIGH
        // Command: 0x23
        // Expected density: 2'b11
        // Expected ACK: 0xB3
        // ----------------------------------
        send_command(8'h23);

        if (ew_density !== 2'b11)
            $fatal(1, "FAIL: EW density should be VERY HIGH");

        wait (tx_start == 1'b1);
        #1;

        if (tx_data !== 8'hB3)
            $fatal(1, "FAIL: EW ACK expected B3, got %h", tx_data);

        $display("PASS: EW density VERY HIGH, ACK = 0x%02h",
                 tx_data);
        tests_passed = tests_passed + 1;

        @(negedge clk);

        // ----------------------------------
        // TEST 3: Status request
        // Command: 0x30
        // NS = 2'b10, EW = 2'b11
        // Expected response = 0xCB
        // ----------------------------------
        send_command(8'h30);

        wait (tx_start == 1'b1);
        #1;

        if (tx_data !== 8'hCB)
            $fatal(1, "FAIL: Status expected CB, got %h", tx_data);

        $display("PASS: Status response = 0x%02h", tx_data);
        tests_passed = tests_passed + 1;

        @(negedge clk);

        // ----------------------------------
        // TEST 4: Invalid command
        // Command: 0xFF
        // Expected error pulse
        // Expected error response: 0xE0
        // ----------------------------------
        @(negedge clk);
        rx_data = 8'hFF;
        rx_valid = 1'b1;

        @(negedge clk);
        rx_valid = 1'b0;

        // Check command_error during its active cycle
        #1;
        if (command_error !== 1'b1)
            $fatal(1, "FAIL: Invalid command was not detected");

        $display("PASS: Invalid command detected");
        tests_passed = tests_passed + 1;

        // Allow pending error response to launch
        wait (tx_start == 1'b1);
        #1;

        if (tx_data !== 8'hE0)
            $fatal(1, "FAIL: Error response expected E0, got %h",
                   tx_data);

        $display("PASS: Error response = 0x%02h", tx_data);

        // Final report
        $display("--------------------------------------");
        $display("Tests passed: %0d / 4", tests_passed);
        $display("ALL COMMAND DECODER TESTS PASSED");
        $display("======================================");

        $finish;
    end

    // Simulation timeout
    initial begin
        #100000;
        $fatal(1, "FAIL: Simulation timeout");
    end

endmodule
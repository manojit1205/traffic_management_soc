`timescale 1ns / 1ps

module tb_uart_loopback;

    reg clk;
    reg rst_n;
    reg tx_start;
    reg [7:0] tx_data;

    wire tx_serial;
    wire tx_busy;
    wire tx_done;

    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_error;

    localparam CLKS_PER_BIT = 16;

    // UART Transmitter
    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) transmitter (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    // UART Receiver
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) receiver (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx_serial (tx_serial),
        .rx_data   (rx_data),
        .rx_valid  (rx_valid),
        .rx_error  (rx_error)
    );

    // Clock generation: 10 ns period
    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;

    // Main test sequence
    initial begin
        rst_n    = 1'b0;
        tx_start = 1'b0;
        tx_data  = 8'h00;

        $display("======================================");
        $display(" UART LOOPBACK TEST");
        $display("======================================");

        // Reset the transmitter and receiver
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        // ----------------------------------
        // TEST 1: Transmit byte 0xA5
        // ----------------------------------
        @(negedge clk);
        tx_data  = 8'hA5;
        tx_start = 1'b1;

        @(negedge clk);
        tx_start = 1'b0;

        wait (rx_valid == 1'b1);

        if (rx_data !== 8'hA5) begin
            $display("FAIL: Expected 0xA5, received 0x%02h",
                     rx_data);
            $fatal(1);
        end
        else begin
            $display("PASS: Received 0x%02h", rx_data);
        end

        // Wait until transmitter is idle
        wait (tx_busy == 1'b0);
        repeat (3) @(negedge clk);

        // ----------------------------------
        // TEST 2: Transmit byte 0x3C
        // ----------------------------------
        tx_data  = 8'h3C;
        tx_start = 1'b1;

        @(negedge clk);
        tx_start = 1'b0;

        wait (rx_valid == 1'b1);

        if (rx_data !== 8'h3C) begin
            $display("FAIL: Expected 0x3C, received 0x%02h",
                     rx_data);
            $fatal(1);
        end
        else begin
            $display("PASS: Received 0x%02h", rx_data);
        end

        // Wait for transmission to finish
        wait (tx_busy == 1'b0);

        $display("--------------------------------------");
        $display("ALL UART LOOPBACK TESTS PASSED");
        $display("--------------------------------------");

        $finish;
    end

    // Detect framing errors
    always @(posedge clk) begin
        if (rst_n && rx_error) begin
            $display("FAIL: UART framing error detected");
            $fatal(1);
        end
    end

    // Safety timeout
    initial begin
        #100000;
        $fatal(1, "FAIL: UART simulation timeout");
    end

endmodule
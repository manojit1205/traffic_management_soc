`timescale 1ns / 1ps

module tb_i2c_master;

// Clock and reset
reg clk;
reg rst_n;

// Master control inputs
reg start;
reg rw;                       // 0 = Write, 1 = Read
reg [6:0] device_addr;
reg [7:0] register_addr;
reg [7:0] write_data;

// Master outputs
wire [7:0] read_data;
wire busy;
wire done;
wire ack_error;

// I2C bus
tri1 sda;
wire scl;

// Simulated slave data
reg slave_drive_low;
reg [7:0] simulated_read_data;

integer test_count;
integer error_count;

// -------------------------------------------------
// DUT: I2C Master
// -------------------------------------------------
i2c_master #(
    .CLK_DIV(10)
) uut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .rw(rw),
    .device_addr(device_addr),
    .register_addr(register_addr),
    .write_data(write_data),
    .read_data(read_data),
    .busy(busy),
    .done(done),
    .ack_error(ack_error),
    .scl(scl),
    .sda(sda)
);

// -------------------------------------------------
// Simplified simulated slave
//
// ACKs the master's ACK state and supplies a
// predefined byte during the master's read state.
// This model intentionally uses the DUT's internal
// FSM, so it is suitable for initial simulation only.
// -------------------------------------------------
assign sda = slave_drive_low ? 1'b0 : 1'bz;

always @(*) begin
    slave_drive_low = 1'b0;

    // ACK the master
    if (uut.state == 4'd4) begin
        slave_drive_low = 1'b1;
    end

    // Supply read data, MSB first
    else if (uut.state == 4'd7) begin
        slave_drive_low =
            ~simulated_read_data[uut.bit_index];
    end
end

// -------------------------------------------------
// Clock: 100 MHz
// -------------------------------------------------
initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// -------------------------------------------------
// Start a transaction
// -------------------------------------------------
task start_transaction;
    begin
        @(negedge clk);
        start = 1'b1;

        // Keep start asserted until the master accepts it
        wait (busy == 1'b1);

        @(negedge clk);
        start = 1'b0;

        wait (done == 1'b1);
        #1;
    end
endtask

// -------------------------------------------------
// Test sequence
// -------------------------------------------------
initial begin
    rst_n = 1'b0;
    start = 1'b0;
    rw = 1'b0;

    device_addr = 7'h48;
    register_addr = 8'h01;
    write_data = 8'h5A;

    simulated_read_data = 8'hA5;

    test_count = 0;
    error_count = 0;

    $display("========================================");
    $display("       I2C MASTER TESTBENCH");
    $display("========================================");

    // Reset
    repeat (5) @(negedge clk);
    rst_n = 1'b1;
    repeat (3) @(negedge clk);

    // ---------------------------------------------
    // TEST 1: Register write
    // ---------------------------------------------
    $display("\nTEST 1: I2C register write");

    rw = 1'b0;
    register_addr = 8'h01;
    write_data = 8'h5A;

    start_transaction;

    test_count = test_count + 1;

    if (ack_error == 1'b0) begin
        $display("PASS: Write transaction completed without ACK error");
    end else begin
        $display("FAIL: ACK error during write");
        error_count = error_count + 1;
    end

    repeat (5) @(negedge clk);

    // ---------------------------------------------
    // TEST 2: Register read
    // ---------------------------------------------
    $display("\nTEST 2: I2C register read");

    rw = 1'b1;
    register_addr = 8'h02;

    start_transaction;

    test_count = test_count + 1;

    if (ack_error == 1'b0) begin
        $display("PASS: Read transaction completed without ACK error");
    end else begin
        $display("FAIL: ACK error during read");
        error_count = error_count + 1;
    end

    if (read_data == simulated_read_data) begin
        $display("PASS: Read data = 0x%02h", read_data);
    end else begin
        $display(
            "FAIL: Expected 0x%02h, received 0x%02h",
            simulated_read_data, read_data
        );
        error_count = error_count + 1;
    end

    // ---------------------------------------------
    // Summary
    // ---------------------------------------------
    repeat (5) @(negedge clk);

    $display("\n========================================");
    $display("Tests executed: %0d", test_count);
    $display("Errors found : %0d", error_count);

    if (error_count == 0)
        $display("RESULT: ALL CHECKS PASSED");
    else
        $display("RESULT: CHECKS FAILED");

    $display("========================================");

    $finish;
end

// Simulation timeout
initial begin
    #200000;
    $display("ERROR: Simulation timeout");
    $finish;
end

endmodule
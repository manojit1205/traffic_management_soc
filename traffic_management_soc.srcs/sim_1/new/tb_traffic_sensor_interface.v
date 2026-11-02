`timescale 1ns / 1ps

module tb_traffic_sensor_interface;

    reg clk;
    reg rst_n;

    wire [1:0] ns_density;
    wire [1:0] ew_density;
    wire scl;
    tri1 sda;

    wire sensors_valid;
    wire sensor_error;

    reg slave_drive_low;
    reg [7:0] ns_sensor_data;
    reg [7:0] ew_sensor_data;

    integer errors;

    // ------------------------------------------------
    // Device Under Test
    // ------------------------------------------------
    traffic_sensor_interface #(
        .CLK_DIV(10),
        .NS_SENSOR_ADDR(7'h48),
        .EW_SENSOR_ADDR(7'h49),
        .SENSOR_REGISTER(8'h00),
        .POLL_INTERVAL(20)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ns_density(ns_density),
        .ew_density(ew_density),
        .scl(scl),
        .sda(sda),
        .sensors_valid(sensors_valid),
        .sensor_error(sensor_error)
    );

    // ------------------------------------------------
    // Simplified simulated I2C slave
    //
    // This model uses internal master states for
    // initial debugging. It is not a protocol-
    // independent I2C slave model.
    // ------------------------------------------------
    assign sda = slave_drive_low ? 1'b0 : 1'bz;

    always @(*) begin
        slave_drive_low = 1'b0;

        // ACK each byte received by the master
        if (dut.i2c_inst.state == 4'd4) begin
            slave_drive_low = 1'b1;
        end

        // Return data for the selected sensor
        else if (dut.i2c_inst.state == 4'd7) begin
            if (dut.i2c_device_addr == 7'h48)
                slave_drive_low =
                    ~ns_sensor_data[dut.i2c_inst.bit_index];
            else if (dut.i2c_device_addr == 7'h49)
                slave_drive_low =
                    ~ew_sensor_data[dut.i2c_inst.bit_index];
            else
                slave_drive_low = 1'b0;
        end
    end

    // ------------------------------------------------
    // Clock: 100 MHz
    // ------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------
    // Test sequence
    // ------------------------------------------------
    initial begin
        rst_n = 1'b0;

        // NS sensor returns density 10 (high)
        ns_sensor_data = 8'h02;

        // EW sensor returns density 11 (very high)
        ew_sensor_data = 8'h03;

        errors = 0;

        $display("========================================");
        $display(" TRAFFIC SENSOR INTERFACE TESTBENCH");
        $display("========================================");

        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        // Allow time for both sensor transactions
        repeat (10000) @(negedge clk);
        #1;

        $display("NS density     = %b", ns_density);
        $display("EW density     = %b", ew_density);
        $display("Sensors valid  = %b", sensors_valid);
        $display("Sensor error   = %b", sensor_error);

        if (ns_density === 2'b10)
            $display("PASS: NS density is HIGH");
        else begin
            $display("FAIL: NS density mismatch");
            errors = errors + 1;
        end

        if (ew_density === 2'b11)
            $display("PASS: EW density is VERY HIGH");
        else begin
            $display("FAIL: EW density mismatch");
            errors = errors + 1;
        end

        if (sensors_valid === 1'b1)
            $display("PASS: Sensor interface reports valid data");
        else begin
            $display("FAIL: Sensor data not marked valid");
            errors = errors + 1;
        end

        if (sensor_error === 1'b0)
            $display("PASS: No sensor error reported");
        else begin
            $display("FAIL: Sensor error reported");
            errors = errors + 1;
        end

        $display("----------------------------------------");
        $display("Total failures: %0d", errors);

        if (errors == 0)
            $display("RESULT: ALL CHECKS PASSED");
        else
            $display("RESULT: TEST FAILED");

        $display("========================================");
        $finish;
    end

    // Timeout
    initial begin
        #2000000;
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule
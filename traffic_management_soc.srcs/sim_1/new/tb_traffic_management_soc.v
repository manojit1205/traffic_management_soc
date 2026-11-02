`timescale 1ns / 1ps

module tb_traffic_management_soc;

    reg clk;
    reg rst_n;
    reg sensor_mode;
    reg uart_driver_start;
    reg [7:0] uart_driver_data;

    wire uart_driver_tx;
    wire uart_tx_pin;
    wire i2c_scl;
    tri1 i2c_sda;

    wire ns_red, ns_yellow, ns_green;
    wire ew_red, ew_yellow, ew_green;
    wire [1:0] ns_density, ew_density;
    wire command_valid, command_error;
    wire sensors_valid, sensor_error;

    // UART driver signals
    wire uart_driver_busy;
    wire uart_driver_done;

    // UART response receiver signals
    wire [7:0] response_data;
    wire response_valid;
    wire response_error;

    // Simulated I2C sensor model
    reg slave_drive_low;
    reg [7:0] ns_sensor_data;
    reg [7:0] ew_sensor_data;

    integer errors;

    // ------------------------------------------------
    // Device under test
    // ------------------------------------------------
    traffic_management_soc #(
        .CLKS_PER_BIT(16),
        .I2C_CLK_DIV(4),
        .SENSOR_POLL_INTERVAL(20),
        .GREEN_LOW_CYCLES(3),
        .GREEN_MED_CYCLES(4),
        .GREEN_HIGH_CYCLES(5),
        .GREEN_VHIGH_CYCLES(6),
        .YELLOW_CYCLES(2),
        .ALL_RED_CYCLES(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx_pin(uart_driver_tx),
        .uart_tx_pin(uart_tx_pin),
        .sensor_mode(sensor_mode),

        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda),

        .ns_red(ns_red),
        .ns_yellow(ns_yellow),
        .ns_green(ns_green),

        .ew_red(ew_red),
        .ew_yellow(ew_yellow),
        .ew_green(ew_green),

        .ns_density(ns_density),
        .ew_density(ew_density),

        .command_valid(command_valid),
        .command_error(command_error),
        .sensors_valid(sensors_valid),
        .sensor_error(sensor_error)
    );

    // ------------------------------------------------
    // UART command transmitter
    // ------------------------------------------------
    uart_tx #(
        .CLKS_PER_BIT(16)
    ) uart_driver (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(uart_driver_start),
        .tx_data(uart_driver_data),
        .tx_serial(uart_driver_tx),
        .tx_busy(uart_driver_busy),
        .tx_done(uart_driver_done)
    );

    // ------------------------------------------------
    // Receive SoC UART response
    // ------------------------------------------------
    uart_rx #(
        .CLKS_PER_BIT(16)
    ) uart_response_receiver (
        .clk(clk),
        .rst_n(rst_n),
        .rx_serial(uart_tx_pin),
        .rx_data(response_data),
        .rx_valid(response_valid),
        .rx_error(response_error)
    );

    // ------------------------------------------------
    // Simplified I2C slave model
    //
    // Uses internal master states for initial debugging.
    // Replace with an independent protocol-level model
    // for final verification.
    // ------------------------------------------------
    assign i2c_sda = slave_drive_low ? 1'b0 : 1'bz;

    always @(*) begin
        slave_drive_low = 1'b0;

        // ACK state in i2c_master
        if (dut.sensor_interface.i2c_inst.state == 4'd4) begin
            slave_drive_low = 1'b1;
        end

        // Send sensor data, MSB first
        else if (dut.sensor_interface.i2c_inst.state == 4'd7) begin
            if (dut.sensor_interface.i2c_device_addr == 7'h48)
                slave_drive_low =
                    ~ns_sensor_data[
                        dut.sensor_interface.i2c_inst.bit_index
                    ];
            else if (dut.sensor_interface.i2c_device_addr == 7'h49)
                slave_drive_low =
                    ~ew_sensor_data[
                        dut.sensor_interface.i2c_inst.bit_index
                    ];
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
    // Send one UART byte
    // ------------------------------------------------
    task send_uart_byte;
        input [7:0] data;
        begin
            wait (uart_driver_busy == 1'b0);

            @(negedge clk);
            uart_driver_data = data;
            uart_driver_start = 1'b1;

            @(negedge clk);
            uart_driver_start = 1'b0;

            wait (uart_driver_done == 1'b1);
            @(negedge clk);
        end
    endtask

    // ------------------------------------------------
    // Test sequence
    // ------------------------------------------------
    initial begin
        rst_n = 1'b0;
        sensor_mode = 1'b1;

        uart_driver_start = 1'b0;
        uart_driver_data = 8'h00;

        // NS density = 10 (high)
        ns_sensor_data = 8'h02;

        // EW density = 11 (very high)
        ew_sensor_data = 8'h03;

        errors = 0;

        $display("======================================");
        $display(" TRAFFIC MANAGEMENT SoC TESTBENCH");
        $display("======================================");

        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        // Allow the sensor interface to poll both sensors
        repeat (12000) @(negedge clk);
        #1;

        $display("\nTEST 1: I2C sensor integration");
        $display("NS density = %b", ns_density);
        $display("EW density = %b", ew_density);
        $display("Sensors valid = %b", sensors_valid);
        $display("Sensor error = %b", sensor_error);

        if (ns_density === 2'b10)
            $display("PASS: NS density");
        else begin
            $display("FAIL: NS density");
            errors = errors + 1;
        end

        if (ew_density === 2'b11)
            $display("PASS: EW density");
        else begin
            $display("FAIL: EW density");
            errors = errors + 1;
        end

        if (sensors_valid === 1'b1)
            $display("PASS: Sensors valid");
        else begin
            $display("FAIL: Sensors not valid");
            errors = errors + 1;
        end

        if (sensor_error === 1'b0)
            $display("PASS: No sensor error");
        else begin
            $display("FAIL: Sensor error detected");
            errors = errors + 1;
        end

        // --------------------------------------------
        // TEST 2: Traffic light safety
        // --------------------------------------------
        $display("\nTEST 2: Traffic light safety");

        if (!(ns_green && ew_green))
            $display("PASS: No simultaneous green signals");
        else begin
            $display("FAIL: Both directions are green");
            errors = errors + 1;
        end

        if (ns_green && (ns_red || ns_yellow)) begin
            $display("FAIL: Invalid NS light combination");
            errors = errors + 1;
        end

        if (ew_green && (ew_red || ew_yellow)) begin
            $display("FAIL: Invalid EW light combination");
            errors = errors + 1;
        end

        // --------------------------------------------
        // TEST 3: UART status request
        // --------------------------------------------
        $display("\nTEST 3: UART status request");

        // Command 0x30 requests the UART density status.
        // UART density registers are independent of sensor
        // density when sensor_mode is enabled.
        send_uart_byte(8'h30);

        wait (response_valid == 1'b1);
        #1;

        $display("UART response = 0x%02h", response_data);

        if (response_data === 8'hC0)
            $display("PASS: UART status response");
        else begin
            $display("FAIL: Expected C0 status response");
            errors = errors + 1;
        end

        // --------------------------------------------
        // Summary
        // --------------------------------------------
        $display("\n======================================");
        $display("TOTAL FAILURES: %0d", errors);

        if (errors == 0)
            $display("RESULT: ALL CHECKS PASSED");
        else
            $display("RESULT: TEST FAILED");

        $display("======================================");

        $finish;
    end

    // Simulation timeout
    initial begin
        #3000000;
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule
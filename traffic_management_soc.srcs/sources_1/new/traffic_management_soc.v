`timescale 1ns / 1ps

module traffic_management_soc #(
    parameter CLKS_PER_BIT = 434,
    parameter I2C_CLK_DIV = 10,
    parameter SENSOR_POLL_INTERVAL = 1000,

    parameter GREEN_LOW_CYCLES  = 5,
    parameter GREEN_MED_CYCLES  = 10,
    parameter GREEN_HIGH_CYCLES = 15,
    parameter GREEN_VHIGH_CYCLES = 20,
    parameter YELLOW_CYCLES = 3,
    parameter ALL_RED_CYCLES = 2
)(
    input wire clk,
    input wire rst_n,

    // UART interface
    input wire uart_rx_pin,
    output wire uart_tx_pin,

    // Select density source
    input wire sensor_mode,

    // I2C sensor interface
    output wire i2c_scl,
    inout wire i2c_sda,

    // Traffic light outputs
    output wire ns_red,
    output wire ns_yellow,
    output wire ns_green,

    output wire ew_red,
    output wire ew_yellow,
    output wire ew_green,

    // Selected density values
    output wire [1:0] ns_density,
    output wire [1:0] ew_density,

    // Status outputs
    output wire command_valid,
    output wire command_error,
    output wire sensors_valid,
    output wire sensor_error
);

    // =================================================
    // UART receiver signals
    // =================================================
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_error;

    // =================================================
    // UART transmitter signals
    // =================================================
    wire [7:0] tx_data;
    wire tx_start;
    wire tx_busy;
    wire tx_done;

    // =================================================
    // Density values received over UART
    // =================================================
    wire [1:0] uart_ns_density;
    wire [1:0] uart_ew_density;

    // =================================================
    // Density values received over I2C
    // =================================================
    wire [1:0] sensor_ns_density;
    wire [1:0] sensor_ew_density;

    // =================================================
    // Select density source
    // =================================================
    assign ns_density =
        sensor_mode ? sensor_ns_density : uart_ns_density;

    assign ew_density =
        sensor_mode ? sensor_ew_density : uart_ew_density;

    // =================================================
    // UART receiver
    // =================================================
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_receiver (
        .clk(clk),
        .rst_n(rst_n),
        .rx_serial(uart_rx_pin),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_error(rx_error)
    );

    // =================================================
    // UART command decoder
    // =================================================
    uart_command_decoder uart_decoder (
        .clk(clk),
        .rst_n(rst_n),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .tx_busy(tx_busy),

        .ns_density(uart_ns_density),
        .ew_density(uart_ew_density),

        .tx_data(tx_data),
        .tx_start(tx_start),
        .command_valid(command_valid),
        .command_error(command_error)
    );

    // =================================================
    // UART transmitter
    // =================================================
    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_transmitter (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_serial(uart_tx_pin),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    // =================================================
    // I2C traffic sensor interface
    // =================================================
    traffic_sensor_interface #(
        .CLK_DIV(I2C_CLK_DIV),
        .NS_SENSOR_ADDR(7'h48),
        .EW_SENSOR_ADDR(7'h49),
        .SENSOR_REGISTER(8'h00),
        .POLL_INTERVAL(SENSOR_POLL_INTERVAL)
    ) sensor_interface (
        .clk(clk),
        .rst_n(rst_n),

        .ns_density(sensor_ns_density),
        .ew_density(sensor_ew_density),

        .scl(i2c_scl),
        .sda(i2c_sda),

        .sensors_valid(sensors_valid),
        .sensor_error(sensor_error)
    );

    // =================================================
    // Adaptive traffic management core
    // =================================================
    traffic_management_core #(
        .GREEN_LOW_CYCLES(GREEN_LOW_CYCLES),
        .GREEN_MED_CYCLES(GREEN_MED_CYCLES),
        .GREEN_HIGH_CYCLES(GREEN_HIGH_CYCLES),
        .GREEN_VHIGH_CYCLES(GREEN_VHIGH_CYCLES),
        .YELLOW_CYCLES(YELLOW_CYCLES),
        .ALL_RED_CYCLES(ALL_RED_CYCLES)
    ) traffic_core (
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

endmodule
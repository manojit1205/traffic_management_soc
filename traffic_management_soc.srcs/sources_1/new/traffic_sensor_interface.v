`timescale 1ns / 1ps

module traffic_sensor_interface #(
    parameter CLK_DIV = 10,
    parameter [6:0] NS_SENSOR_ADDR = 7'h48,
    parameter [6:0] EW_SENSOR_ADDR = 7'h49,
    parameter [7:0] SENSOR_REGISTER = 8'h00,
    parameter POLL_INTERVAL = 1000
)(
    input  wire       clk,
    input  wire       rst_n,

    output reg  [1:0] ns_density,
    output reg  [1:0] ew_density,

    output wire       scl,
    inout  wire       sda,

    output reg        sensors_valid,
    output reg        sensor_error
);

    // I2C master signals
    reg        i2c_start;
    reg        i2c_rw;
    reg  [6:0] i2c_device_addr;
    reg  [7:0] i2c_register_addr;
    reg  [7:0] i2c_write_data;

    wire [7:0] i2c_read_data;
    wire       i2c_busy;
    wire       i2c_done;
    wire       i2c_ack_error;

    // Controller states
    localparam IDLE       = 3'd0;
    localparam START_NS   = 3'd1;
    localparam WAIT_NS    = 3'd2;
    localparam START_EW   = 3'd3;
    localparam WAIT_EW    = 3'd4;
    localparam POLL_DELAY = 3'd5;

    reg [2:0] state;
    reg [31:0] poll_count;

    // I2C master instance
    i2c_master #(
        .CLK_DIV(CLK_DIV)
    ) i2c_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(i2c_start),
        .rw(i2c_rw),
        .device_addr(i2c_device_addr),
        .register_addr(i2c_register_addr),
        .write_data(i2c_write_data),
        .read_data(i2c_read_data),
        .busy(i2c_busy),
        .done(i2c_done),
        .ack_error(i2c_ack_error),
        .scl(scl),
        .sda(sda)
    );

    // Poll both sensors continuously
    always @(posedge clk) begin
        if (!rst_n) begin
            state             <= IDLE;
            i2c_start         <= 1'b0;
            i2c_rw            <= 1'b1; // Read
            i2c_device_addr   <= NS_SENSOR_ADDR;
            i2c_register_addr <= SENSOR_REGISTER;
            i2c_write_data    <= 8'h00;

            ns_density        <= 2'b00;
            ew_density        <= 2'b00;

            sensors_valid     <= 1'b0;
            sensor_error      <= 1'b0;
            poll_count        <= 32'd0;
        end else begin
            case (state)

                IDLE: begin
                    i2c_start <= 1'b0;
                    poll_count <= 0;
                    sensor_error <= 1'b0;
                    state <= START_NS;
                end

                START_NS: begin
                    i2c_device_addr   <= NS_SENSOR_ADDR;
                    i2c_register_addr <= SENSOR_REGISTER;
                    i2c_rw            <= 1'b1;
                    i2c_start         <= 1'b1;
                    state             <= WAIT_NS;
                end

                WAIT_NS: begin
                    // Hold start until the master accepts it.
                    if (i2c_busy)
                        i2c_start <= 1'b0;

                    if (i2c_done) begin
                        i2c_start <= 1'b0;

                        if (i2c_ack_error) begin
                            sensor_error <= 1'b1;
                            sensors_valid <= 1'b0;
                        end else begin
                            ns_density <= i2c_read_data[1:0];
                        end

                        state <= START_EW;
                    end
                end

                START_EW: begin
                    i2c_device_addr   <= EW_SENSOR_ADDR;
                    i2c_register_addr <= SENSOR_REGISTER;
                    i2c_rw            <= 1'b1;
                    i2c_start         <= 1'b1;
                    state             <= WAIT_EW;
                end

                WAIT_EW: begin
                    if (i2c_busy)
                        i2c_start <= 1'b0;

                    if (i2c_done) begin
                        i2c_start <= 1'b0;

                        if (i2c_ack_error) begin
                            sensor_error <= 1'b1;
                            sensors_valid <= 1'b0;
                        end else begin
                            ew_density <= i2c_read_data[1:0];

                            // Both reads completed without error.
                            if (!sensor_error)
                                sensors_valid <= 1'b1;
                        end

                        poll_count <= 0;
                        state <= POLL_DELAY;
                    end
                end

                POLL_DELAY: begin
                    i2c_start <= 1'b0;

                    if (poll_count >= POLL_INTERVAL - 1) begin
                        poll_count <= 0;
                        state <= START_NS;
                    end else begin
                        poll_count <= poll_count + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    i2c_start <= 1'b0;
                end

            endcase
        end
    end

endmodule
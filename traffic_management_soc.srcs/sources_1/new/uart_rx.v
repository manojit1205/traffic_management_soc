`timescale 1ns / 1ps

module uart_rx #(
    parameter CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_serial,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        rx_error
);

    // FSM state encoding
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA  = 2'd2;
    localparam [1:0] STOP  = 2'd3;

    reg [1:0]  state;
    reg [31:0] clock_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_buffer;

    // Two-stage synchronizer for asynchronous UART input
    reg rx_sync1;
    reg rx_sync2;

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end
        else begin
            rx_sync1 <= rx_serial;
            rx_sync2 <= rx_sync1;
        end
    end

    // UART receiver FSM
    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= IDLE;
            clock_count <= 32'd0;
            bit_index   <= 3'd0;
            data_buffer <= 8'd0;
            rx_data     <= 8'd0;
            rx_valid    <= 1'b0;
            rx_error    <= 1'b0;
        end
        else begin
            // Default: status signals are one-cycle pulses
            rx_valid <= 1'b0;
            rx_error <= 1'b0;

            case (state)

                IDLE: begin
                    clock_count <= 32'd0;
                    bit_index   <= 3'd0;

                    // UART start bit is active low
                    if (rx_sync2 == 1'b0) begin
                        state <= START;
                    end
                end

                START: begin
                    // Sample near the middle of the start bit
                    if (clock_count == (CLKS_PER_BIT / 2) - 1) begin
                        clock_count <= 32'd0;

                        if (rx_sync2 == 1'b0) begin
                            state <= DATA;
                        end
                        else begin
                            // False start-bit detection
                            state <= IDLE;
                        end
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                DATA: begin
                    // Sample each data bit at its center
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 32'd0;

                        // UART sends least-significant bit first
                        data_buffer[bit_index] <= rx_sync2;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end
                        else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STOP: begin
                    // Check the stop bit after one bit interval
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 32'd0;
                        state       <= IDLE;

                        if (rx_sync2 == 1'b1) begin
                            rx_data  <= data_buffer;
                            rx_valid <= 1'b1;
                        end
                        else begin
                            // Invalid stop bit: framing error
                            rx_error <= 1'b1;
                        end
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                default: begin
                    state       <= IDLE;
                    clock_count <= 32'd0;
                    bit_index   <= 3'd0;
                end

            endcase
        end
    end

endmodule
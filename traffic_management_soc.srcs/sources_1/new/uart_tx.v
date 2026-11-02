`timescale 1ns / 1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_serial,
    output reg        tx_busy,
    output reg        tx_done
);

    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA  = 2'd2;
    localparam [1:0] STOP  = 2'd3;

    reg [1:0] state;
    reg [31:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] data_buffer;

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= IDLE;
            clock_count <= 0;
            bit_index   <= 0;
            data_buffer <= 0;
            tx_serial   <= 1'b1;
            tx_busy     <= 1'b0;
            tx_done     <= 1'b0;
        end
        else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx_serial   <= 1'b1;
                    tx_busy     <= 1'b0;
                    clock_count <= 0;
                    bit_index   <= 0;

                    if (tx_start) begin
                        data_buffer <= tx_data;
                        tx_busy     <= 1'b1;
                        tx_serial   <= 1'b0;
                        state       <= START;
                    end
                end

                START: begin
                    tx_busy <= 1'b1;

                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 0;
                        bit_index   <= 0;
                        tx_serial   <= data_buffer[0];
                        state       <= DATA;
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                DATA: begin
                    tx_busy <= 1'b1;

                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 0;

                        if (bit_index == 7) begin
                            tx_serial <= 1'b1;
                            state     <= STOP;
                        end
                        else begin
                            bit_index <= bit_index + 1'b1;
                            tx_serial <= data_buffer[bit_index + 1'b1];
                        end
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STOP: begin
                    tx_busy <= 1'b1;

                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 0;
                        tx_serial   <= 1'b1;
                        tx_busy     <= 1'b0;
                        tx_done     <= 1'b1;
                        state       <= IDLE;
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                default: begin
                    state       <= IDLE;
                    tx_serial   <= 1'b1;
                    tx_busy     <= 1'b0;
                    clock_count <= 0;
                end
            endcase
        end
    end

endmodule
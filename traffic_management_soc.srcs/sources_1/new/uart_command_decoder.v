`timescale 1ns / 1ps

module uart_command_decoder (
    input  wire       clk,
    input  wire       rst_n,

    // UART receiver interface
    input  wire [7:0] rx_data,
    input  wire       rx_valid,

    // Traffic density configuration
    output reg  [1:0] ns_density,
    output reg  [1:0] ew_density,

    // Response interface to UART transmitter
    input  wire       tx_busy,
    output reg  [7:0] tx_data,
    output reg        tx_start,

    // Command status
    output reg        command_valid,
    output reg        command_error
);

    reg response_pending;
    reg [7:0] response_buffer;

    always @(posedge clk) begin
        if (!rst_n) begin
            ns_density    <= 2'b00;
            ew_density    <= 2'b00;

            tx_data       <= 8'h00;
            tx_start      <= 1'b0;

            command_valid <= 1'b0;
            command_error <= 1'b0;

            response_pending <= 1'b0;
            response_buffer  <= 8'h00;
        end
        else begin
            // Default: pulse outputs for one clock cycle
            tx_start      <= 1'b0;
            command_valid <= 1'b0;
            command_error <= 1'b0;

            // Decode a newly received UART command
            if (rx_valid) begin
                case (rx_data)

                    // North-South density commands
                    8'h10: begin
                        ns_density <= 2'b00;
                        response_buffer <= 8'hA0;
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    8'h11: begin
                        ns_density <= 2'b01;
                        response_buffer <= 8'hA1;
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    8'h12: begin
                        ns_density <= 2'b10;
                        response_buffer <= 8'hA2;
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    8'h13: begin
                        ns_density <= 2'b11;
                        response_buffer <= 8'hA3;
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    // East-West density commands
                    8'h20: begin
                        ew_density <= 2'b00;
                        response_buffer <= 8'hB0;
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    8'h21: begin
                        ew_density <= 2'b01;
                        response_buffer <= 8'hB1;
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    8'h22: begin
                        ew_density <= 2'b10;
                        response_buffer <= 8'hB2;
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    8'h23: begin
                        ew_density <= 2'b11;
                        response_buffer <= 8'hB3;
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    // Status request:
                    // [7:4] = C, [3:2] = NS, [1:0] = EW
                    8'h30: begin
                        response_buffer <= {
                            4'hC, ns_density, ew_density
                        };
                        response_pending <= 1'b1;
                        command_valid <= 1'b1;
                    end

                    default: begin
                        response_buffer <= 8'hE0;
                        response_pending <= 1'b1;
                        command_error <= 1'b1;
                    end

                endcase
            end

            // Launch a pending response when the transmitter is idle.
            // A single response can be queued.
            if (response_pending && !tx_busy && !rx_valid) begin
                tx_data <= response_buffer;
                tx_start <= 1'b1;
                response_pending <= 1'b0;
            end
        end
    end

endmodule
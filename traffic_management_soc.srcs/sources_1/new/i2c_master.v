`timescale 1ns / 1ps

module i2c_master #(
    parameter CLK_DIV = 10
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire       start,
    input  wire       rw,           // 0 = Write, 1 = Read
    input  wire [6:0] device_addr,
    input  wire [7:0] register_addr,
    input  wire [7:0] write_data,

    output reg  [7:0] read_data,
    output reg        busy,
    output reg        done,
    output reg        ack_error,

    output reg        scl,
    inout  wire       sda
);

    // Open-drain SDA: drive LOW or release the line.
    reg sda_drive_low;
    wire sda_in;

    assign sda = sda_drive_low ? 1'b0 : 1'bz;
    assign sda_in = sda;

    localparam IDLE     = 4'd0;
    localparam START1   = 4'd1;
    localparam START2   = 4'd2;
    localparam SEND     = 4'd3;
    localparam ACK      = 4'd4;
    localparam RESTART1 = 4'd5;
    localparam RESTART2 = 4'd6;
    localparam RECV     = 4'd7;
    localparam NACK     = 4'd8;
    localparam STOP1    = 4'd9;
    localparam STOP2    = 4'd10;
    localparam STOP3    = 4'd11;

    reg [3:0] state;
    reg [1:0] phase;
    reg [7:0] shift_reg;
    reg [2:0] bit_index;
    reg [1:0] stage;
    reg [31:0] divider_count;

    wire tick = (divider_count >= CLK_DIV - 1);

    // Clock divider
    always @(posedge clk) begin
        if (!rst_n)
            divider_count <= 0;
        else if (tick)
            divider_count <= 0;
        else
            divider_count <= divider_count + 1'b1;
    end

    // I2C master state machine
    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= IDLE;
            phase         <= 0;
            shift_reg     <= 0;
            bit_index     <= 7;
            stage         <= 0;
            read_data     <= 0;
            busy          <= 0;
            done          <= 0;
            ack_error     <= 0;
            scl           <= 1'b1;
            sda_drive_low <= 1'b0;
        end else begin
            done <= 1'b0;

            if (tick) begin
                case (state)

                    IDLE: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;
                        busy          <= 1'b0;

                        if (start) begin
                            busy      <= 1'b1;
                            ack_error <= 1'b0;
                            stage     <= 0;
                            phase     <= 0;
                            state     <= START1;
                        end
                    end

                    // Generate START condition
                    START1: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b1;
                        state         <= START2;
                    end

                    START2: begin
                        scl       <= 1'b0;
                        shift_reg <= {device_addr, 1'b0};
                        bit_index <= 7;
                        phase     <= 0;
                        stage     <= 0;
                        state     <= SEND;
                    end

                    // Send one byte, MSB first
                    SEND: begin
                        case (phase)
                            0: begin
                                scl <= 1'b0;
                                sda_drive_low <= ~shift_reg[bit_index];
                                phase <= 1;
                            end

                            1: begin
                                scl <= 1'b1;
                                phase <= 2;
                            end

                            2: begin
                                scl <= 1'b0;
                                if (bit_index == 0) begin
                                    phase <= 0;
                                    state <= ACK;
                                end else begin
                                    bit_index <= bit_index - 1'b1;
                                    phase <= 0;
                                end
                            end
                        endcase
                    end

                    // Receive ACK from slave
                    ACK: begin
                        case (phase)
                            0: begin
                                scl <= 1'b0;
                                sda_drive_low <= 1'b0;
                                phase <= 1;
                            end

                            1: begin
                                scl <= 1'b1;
                                if (sda_in !== 1'b0)
                                    ack_error <= 1'b1;
                                phase <= 2;
                            end

                            2: begin
                                scl <= 1'b0;
                                phase <= 0;

                                if (sda_in !== 1'b0) begin
                                    state <= STOP1;
                                end else begin
                                    case (stage)
                                        0: begin
                                            shift_reg <= register_addr;
                                            bit_index <= 7;
                                            stage <= 1;
                                            state <= SEND;
                                        end

                                        1: begin
                                            if (rw) begin
                                                state <= RESTART1;
                                            end else begin
                                                shift_reg <= write_data;
                                                bit_index <= 7;
                                                stage <= 2;
                                                state <= SEND;
                                            end
                                        end

                                        2: begin
                                            state <= STOP1;
                                        end

                                        3: begin
                                            read_data <= 0;
                                            bit_index <= 7;
                                            state <= RECV;
                                        end

                                        default: state <= STOP1;
                                    endcase
                                end
                            end
                        endcase
                    end

                    // Repeated START for register read
                    RESTART1: begin
                        scl           <= 1'b1;
                        sda_drive_low <= 1'b0;
                        state         <= RESTART2;
                    end

                    RESTART2: begin
                        sda_drive_low <= 1'b1;
                        shift_reg <= {device_addr, 1'b1};
                        bit_index <= 7;
                        phase     <= 0;
                        stage     <= 3;
                        state     <= SEND;
                    end

                    // Receive one byte from slave
                    RECV: begin
                        case (phase)
                            0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= 1'b0;
                                phase         <= 1;
                            end

                            1: begin
                                scl <= 1'b1;
                                read_data[bit_index] <= sda_in;
                                phase <= 2;
                            end

                            2: begin
                                scl <= 1'b0;
                                if (bit_index == 0) begin
                                    phase <= 0;
                                    state <= NACK;
                                end else begin
                                    bit_index <= bit_index - 1'b1;
                                    phase <= 0;
                                end
                            end
                        endcase
                    end

                    // Master NACK after reading one byte
                    NACK: begin
                        case (phase)
                            0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= 1'b0;
                                phase         <= 1;
                            end

                            1: begin
                                scl   <= 1'b1;
                                phase <= 2;
                            end

                            2: begin
                                scl   <= 1'b0;
                                phase <= 0;
                                state <= STOP1;
                            end
                        endcase
                    end

                    // Generate STOP condition
                    STOP1: begin
                        scl           <= 1'b0;
                        sda_drive_low <= 1'b1;
                        state         <= STOP2;
                    end

                    STOP2: begin
                        scl <= 1'b1;
                        state <= STOP3;
                    end

                    STOP3: begin
                        sda_drive_low <= 1'b0;
                        scl           <= 1'b1;
                        busy          <= 1'b0;
                        done          <= 1'b1;
                        state         <= IDLE;
                    end

                    default: state <= IDLE;

                endcase
            end
        end
    end

endmodule
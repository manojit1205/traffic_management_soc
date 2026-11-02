`timescale 1ns / 1ps

module traffic_controller #(
    parameter GREEN_CYCLES   = 10,
    parameter YELLOW_CYCLES  = 3,
    parameter ALL_RED_CYCLES = 2
)(
    input  wire clk,
    input  wire rst_n,

    output reg ns_red,
    output reg ns_yellow,
    output reg ns_green,

    output reg ew_red,
    output reg ew_yellow,
    output reg ew_green
);

    // State encoding
    localparam [2:0] NS_GREEN_STATE  = 3'd0;
    localparam [2:0] NS_YELLOW_STATE = 3'd1;
    localparam [2:0] ALL_RED_1_STATE = 3'd2;
    localparam [2:0] EW_GREEN_STATE  = 3'd3;
    localparam [2:0] EW_YELLOW_STATE = 3'd4;
    localparam [2:0] ALL_RED_2_STATE = 3'd5;

    reg [2:0] state;
    reg [31:0] timer_count;

    // State and timer control
    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= NS_GREEN_STATE;
            timer_count <= 32'd0;
        end
        else begin
            case (state)

                NS_GREEN_STATE: begin
                    if (timer_count >= GREEN_CYCLES - 1) begin
                        state       <= NS_YELLOW_STATE;
                        timer_count <= 32'd0;
                    end
                    else begin
                        timer_count <= timer_count + 1'b1;
                    end
                end

                NS_YELLOW_STATE: begin
                    if (timer_count >= YELLOW_CYCLES - 1) begin
                        state       <= ALL_RED_1_STATE;
                        timer_count <= 32'd0;
                    end
                    else begin
                        timer_count <= timer_count + 1'b1;
                    end
                end

                ALL_RED_1_STATE: begin
                    if (timer_count >= ALL_RED_CYCLES - 1) begin
                        state       <= EW_GREEN_STATE;
                        timer_count <= 32'd0;
                    end
                    else begin
                        timer_count <= timer_count + 1'b1;
                    end
                end

                EW_GREEN_STATE: begin
                    if (timer_count >= GREEN_CYCLES - 1) begin
                        state       <= EW_YELLOW_STATE;
                        timer_count <= 32'd0;
                    end
                    else begin
                        timer_count <= timer_count + 1'b1;
                    end
                end

                EW_YELLOW_STATE: begin
                    if (timer_count >= YELLOW_CYCLES - 1) begin
                        state       <= ALL_RED_2_STATE;
                        timer_count <= 32'd0;
                    end
                    else begin
                        timer_count <= timer_count + 1'b1;
                    end
                end

                ALL_RED_2_STATE: begin
                    if (timer_count >= ALL_RED_CYCLES - 1) begin
                        state       <= NS_GREEN_STATE;
                        timer_count <= 32'd0;
                    end
                    else begin
                        timer_count <= timer_count + 1'b1;
                    end
                end

                default: begin
                    state       <= NS_GREEN_STATE;
                    timer_count <= 32'd0;
                end

            endcase
        end
    end

    // Decode the current state into traffic-light outputs
    always @(*) begin
        // Default: all directions red
        ns_red    = 1'b1;
        ns_yellow = 1'b0;
        ns_green  = 1'b0;

        ew_red    = 1'b1;
        ew_yellow = 1'b0;
        ew_green  = 1'b0;

        case (state)

            NS_GREEN_STATE: begin
                ns_red   = 1'b0;
                ns_green = 1'b1;
            end

            NS_YELLOW_STATE: begin
                ns_red    = 1'b0;
                ns_yellow = 1'b1;
            end

            ALL_RED_1_STATE: begin
                // Both directions remain red
            end

            EW_GREEN_STATE: begin
                ew_red   = 1'b0;
                ew_green = 1'b1;
            end

            EW_YELLOW_STATE: begin
                ew_red    = 1'b0;
                ew_yellow = 1'b1;
            end

            ALL_RED_2_STATE: begin
                // Both directions remain red
            end

            default: begin
                // Safe output default: all red
            end

        endcase
    end

endmodule

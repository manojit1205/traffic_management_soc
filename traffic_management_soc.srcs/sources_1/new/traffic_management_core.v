`timescale 1ns / 1ps

module traffic_management_core #(
    parameter GREEN_LOW_CYCLES   = 5,
    parameter GREEN_MED_CYCLES   = 10,
    parameter GREEN_HIGH_CYCLES  = 15,
    parameter GREEN_VHIGH_CYCLES = 20,
    parameter YELLOW_CYCLES      = 3,
    parameter ALL_RED_CYCLES     = 2
)(
    input wire clk,
    input wire rst_n,

    // Traffic density: 00=low, 01=medium,
    //                  10=high, 11=very high
    input wire [1:0] ns_density,
    input wire [1:0] ew_density,

    output reg ns_red,
    output reg ns_yellow,
    output reg ns_green,

    output reg ew_red,
    output reg ew_yellow,
    output reg ew_green
);

    // FSM state encoding
    localparam [2:0] NS_GREEN  = 3'd0;
    localparam [2:0] NS_YELLOW = 3'd1;
    localparam [2:0] ALL_RED_1 = 3'd2;
    localparam [2:0] EW_GREEN  = 3'd3;
    localparam [2:0] EW_YELLOW = 3'd4;
    localparam [2:0] ALL_RED_2 = 3'd5;

    reg [2:0] state;

    reg [31:0] active_green_duration;
    reg [31:0] phase_duration;

    wire timer_done;

    // Convert density into a green-light duration.
    function [31:0] get_green_duration;
        input [1:0] density;
        begin
            case (density)
                2'b00: get_green_duration = GREEN_LOW_CYCLES;
                2'b01: get_green_duration = GREEN_MED_CYCLES;
                2'b10: get_green_duration = GREEN_HIGH_CYCLES;
                2'b11: get_green_duration = GREEN_VHIGH_CYCLES;
                default: get_green_duration = GREEN_LOW_CYCLES;
            endcase
        end
    endfunction

    // Select the duration for the active phase.
    always @(*) begin
        case (state)
            NS_GREEN, EW_GREEN:
                phase_duration = active_green_duration;

            NS_YELLOW, EW_YELLOW:
                phase_duration = YELLOW_CYCLES;

            ALL_RED_1, ALL_RED_2:
                phase_duration = ALL_RED_CYCLES;

            default:
                phase_duration = ALL_RED_CYCLES;
        endcase
    end

    // Shared phase timer
    configurable_timer timer_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .enable   (1'b1),
        .clear    (1'b0),
        .duration (phase_duration),
        .done     (timer_done)
    );

    // Traffic controller FSM.
    // Sample density when entering each green phase.
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= NS_GREEN;
            active_green_duration <=
                get_green_duration(ns_density);
        end
        else if (timer_done) begin
            case (state)

                NS_GREEN: begin
                    state <= NS_YELLOW;
                end

                NS_YELLOW: begin
                    state <= ALL_RED_1;
                end

                ALL_RED_1: begin
                    state <= EW_GREEN;
                    active_green_duration <=
                        get_green_duration(ew_density);
                end

                EW_GREEN: begin
                    state <= EW_YELLOW;
                end

                EW_YELLOW: begin
                    state <= ALL_RED_2;
                end

                ALL_RED_2: begin
                    state <= NS_GREEN;
                    active_green_duration <=
                        get_green_duration(ns_density);
                end

                default: begin
                    state <= ALL_RED_1;
                end

            endcase
        end
    end

    // Traffic-light output decoder.
    // Default outputs are all red.
    always @(*) begin
        ns_red    = 1'b1;
        ns_yellow = 1'b0;
        ns_green  = 1'b0;

        ew_red    = 1'b1;
        ew_yellow = 1'b0;
        ew_green  = 1'b0;

        case (state)

            NS_GREEN: begin
                ns_red   = 1'b0;
                ns_green = 1'b1;
            end

            NS_YELLOW: begin
                ns_red    = 1'b0;
                ns_yellow = 1'b1;
            end

            ALL_RED_1: begin
                // Both directions red
            end

            EW_GREEN: begin
                ew_red   = 1'b0;
                ew_green = 1'b1;
            end

            EW_YELLOW: begin
                ew_red    = 1'b0;
                ew_yellow = 1'b1;
            end

            ALL_RED_2: begin
                // Both directions red
            end

            default: begin
                // Safe default: all red
            end

        endcase
    end

endmodule

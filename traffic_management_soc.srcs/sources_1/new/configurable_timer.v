`timescale 1ns / 1ps

module configurable_timer #(
    parameter COUNTER_WIDTH = 32
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        clear,
    input  wire [31:0] duration,
    output reg         done
);

    reg [COUNTER_WIDTH-1:0] count;

    always @(posedge clk) begin
        if (!rst_n) begin
            count <= {COUNTER_WIDTH{1'b0}};
            done  <= 1'b0;
        end
        else if (clear) begin
            count <= {COUNTER_WIDTH{1'b0}};
            done  <= 1'b0;
        end
        else if (done) begin
            count <= {COUNTER_WIDTH{1'b0}};
            done  <= 1'b0;
        end
        else if (!enable) begin
            done <= 1'b0;
        end
        else if (duration == 0) begin
            count <= {COUNTER_WIDTH{1'b0}};
            done  <= 1'b1;
        end
        else if (count >= duration - 1'b1) begin
            count <= {COUNTER_WIDTH{1'b0}};
            done  <= 1'b1;
        end
        else begin
            count <= count + 1'b1;
            done  <= 1'b0;
        end
    end

endmodule

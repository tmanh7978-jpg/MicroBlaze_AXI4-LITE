
`timescale 1ns / 1ps

module led_controller (
    input  wire       clk,
    input  wire       resetn,
    input  wire       enable,
    input  wire       blink_mode,
    input  wire [3:0] led_data,
    output wire [3:0] led
);

    // Clock 100 MHz
    // 0.5 giay = 50,000,000 clock cycles
    parameter integer HALF_PERIOD = 50_000_000;

    reg [31:0] counter;
    reg blink_state;

    always @(posedge clk) begin
        if (!resetn) begin
            counter     <= 32'd0;
            blink_state <= 1'b1;
        end
        else if (!enable || !blink_mode) begin
            counter     <= 32'd0;
            blink_state <= 1'b1;
        end
        else if (counter == HALF_PERIOD - 1) begin
            counter     <= 32'd0;
            blink_state <= ~blink_state;
        end
        else begin
            counter <= counter + 1'b1;
        end
    end

    assign led = !enable ? 4'b0000 :
                 blink_mode ?
                 (blink_state ? led_data : 4'b0000) :
                 led_data;

endmodule

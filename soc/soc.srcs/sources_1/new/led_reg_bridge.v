
`timescale 1ns / 1ps

module led_reg_bridge (
    input wire clk,
    input wire resetn,

    // AXI4-Lite Slave - Write interface
    input wire write,
    input wire [5:0] write_addrs,
    input wire [31:0] write_data,
    input wire [3:0] write_strobe,
    output wire write_done,
    output wire write_error,

    // AXI4-Lite Slave - Read interface
    input wire read,
    input wire [5:0] read_addrs,
    output reg [31:0] read_data,
    output wire read_done,
    output wire read_error,

    // LED Controller interface
    output reg [3:0] led_data,
    output reg enable,
    output reg blink_mode
);

    // Immediate completion for simple registers
    assign write_done  = 1'b1;
    assign read_done   = 1'b1;
    assign write_error = 1'b0;
    assign read_error  = 1'b0;

    // Write registers
    always @(posedge clk) begin
        if (!resetn) begin
            led_data   <= 4'b0000;
            enable     <= 1'b0;
            blink_mode <= 1'b0;
        end
        else if (write && write_strobe[0]) begin
            case (write_addrs)
                6'h00: led_data <= write_data[3:0];

                6'h04: begin
                    enable     <= write_data[0];
                    blink_mode <= write_data[1];
                end

                default: ;
            endcase
        end
    end

    // Read registers
    always @(*) begin
        case (read_addrs)
            6'h00: read_data = {28'b0, led_data};

            6'h04: read_data =
                {30'b0, blink_mode, enable};

            default: read_data = 32'b0;
        endcase
    end

endmodule

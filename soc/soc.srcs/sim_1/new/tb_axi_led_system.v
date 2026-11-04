
`timescale 1ns / 1ps
// Pure Verilog-2001 testbench for AXI4-Lite LED peripheral.
// Six cases match the LED_DATA/LED_CTRL combinations from main.c.
// This tests the peripheral, NOT MicroBlaze execution of the ELF.

module tb_axi_led_system;

    parameter BLINK_HALF_CYCLES = 4;
    parameter MAX_WAIT = 100;

    reg clk;
    reg resetn;

    initial clk = 1'b0;
    always #5 clk = ~clk;  // 100 MHz

    // AXI4-Lite master
    reg  [3:0]  s_axi_awaddr;
    reg  [2:0]  s_axi_awprot;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    reg  [3:0]  s_axi_araddr;
    reg  [2:0]  s_axi_arprot;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    wire        gp_write, gp_read;
    wire [5:0]  gp_write_addrs, gp_read_addrs;
    wire [31:0] gp_write_data, gp_read_data;
    wire [3:0]  gp_write_strobe;
    wire        gp_write_done, gp_write_error;
    wire        gp_read_done, gp_read_error;

    wire [3:0] led_data;
    wire       enable, blink_mode;
    wire [3:0] led;

    // AXI4-Lite Slave
    axi_lite_slave_v1_0 #(
        .GP_ADDR_WIDTH(6),
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(4)
    ) dut_axi (
        .write(gp_write),
        .write_addrs(gp_write_addrs),
        .write_data(gp_write_data),
        .write_strobe(gp_write_strobe),
        .write_error(gp_write_error),
        .write_done(gp_write_done),
        .read(gp_read),
        .read_addrs(gp_read_addrs),
        .read_data(gp_read_data),
        .read_error(gp_read_error),
        .read_done(gp_read_done),
        .s_axi_aclk(clk),
        .s_axi_aresetn(resetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    // LED register bridge
    led_reg_bridge dut_bridge (
        .clk(clk),
        .resetn(resetn),
        .write(gp_write),
        .write_addrs(gp_write_addrs),
        .write_data(gp_write_data),
        .write_strobe(gp_write_strobe),
        .write_done(gp_write_done),
        .write_error(gp_write_error),
        .read(gp_read),
        .read_addrs(gp_read_addrs),
        .read_data(gp_read_data),
        .read_done(gp_read_done),
        .read_error(gp_read_error),
        .led_data(led_data),
        .enable(enable),
        .blink_mode(blink_mode)
    );

    // LED Controller
    led_controller #(
        .HALF_PERIOD(BLINK_HALF_CYCLES)
    ) dut_led (
        .clk(clk),
        .resetn(resetn),
        .enable(enable),
        .blink_mode(blink_mode),
        .led_data(led_data),
        .led(led)
    );

    integer current_case_number;
    integer passed_cases;
    integer transactions;

    reg [3:0] current_led_data;
    reg [3:0] current_led_ctrl;

    // Error handling
    task stop_error;
        input [8*128-1:0] reason;
        begin
            $display("[FAIL] case=%0d time=%0t : %0s",
                     current_case_number, $time, reason);
            $finish;
        end
    endtask

    // AXI4-Lite write transaction
    task axi_write;
        input [3:0] address;
        input [31:0] value;

        integer timeout;
        reg aw_done, w_done;

        begin
            @(negedge clk);

            s_axi_awaddr  = address;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = value;
            s_axi_wstrb   = 4'b1111;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b0;

            aw_done = 1'b0;
            w_done  = 1'b0;
            timeout = 0;

            while (!(aw_done && w_done)) begin
                @(posedge clk);

                if (s_axi_awvalid && s_axi_awready)
                    aw_done = 1'b1;

                if (s_axi_wvalid && s_axi_wready)
                    w_done = 1'b1;

                @(negedge clk);

                if (aw_done)
                    s_axi_awvalid = 1'b0;

                if (w_done)
                    s_axi_wvalid = 1'b0;

                timeout = timeout + 1;

                if (timeout > MAX_WAIT)
                    stop_error("AXI AW/W timeout");
            end

            timeout = 0;

            while (s_axi_bvalid !== 1'b1) begin
                @(negedge clk);
                timeout = timeout + 1;

                if (timeout > MAX_WAIT)
                    stop_error("AXI BVALID timeout");
            end

            if (s_axi_bresp !== 2'b00)
                stop_error("AXI write BRESP not OKAY");

            @(negedge clk);
            s_axi_bready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            s_axi_bready = 1'b0;

            transactions = transactions + 1;
        end
    endtask

    // AXI4-Lite read transaction
    task axi_read;
        input [3:0] address;
        input [31:0] expected;

        integer timeout;
        reg ar_done;

        begin
            @(negedge clk);

            s_axi_araddr  = address;
            s_axi_arvalid = 1'b1;
            s_axi_rready  = 1'b0;

            ar_done = 1'b0;
            timeout = 0;

            while (!ar_done) begin
                @(posedge clk);

                if (s_axi_arvalid && s_axi_arready)
                    ar_done = 1'b1;

                @(negedge clk);

                if (ar_done)
                    s_axi_arvalid = 1'b0;

                timeout = timeout + 1;

                if (timeout > MAX_WAIT)
                    stop_error("AXI ARREADY timeout");
            end

            timeout = 0;

            while (s_axi_rvalid !== 1'b1) begin
                @(negedge clk);
                timeout = timeout + 1;

                if (timeout > MAX_WAIT)
                    stop_error("AXI RVALID timeout");
            end

            if (s_axi_rresp !== 2'b00 ||
                s_axi_rdata !== expected) begin

                $display("READ ERROR addr=%h expected=%h actual=%h",
                         address, expected, s_axi_rdata);

                stop_error("AXI readback mismatch");
            end

            @(negedge clk);
            s_axi_rready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            s_axi_rready = 1'b0;

            transactions = transactions + 1;
        end
    endtask

    // Verify blinking functionality
    task check_blink;
        input [3:0] pattern;

        integer i;
        integer on_count;
        integer off_count;
        integer transitions;
        integer last_change;

        reg [3:0] prev_led;

        begin
            on_count = 0;
            off_count = 0;
            transitions = 0;
            last_change = -1;
            prev_led = led;

            for (i = 0; i < BLINK_HALF_CYCLES*8; i = i+1) begin

                @(posedge clk);
                #1;

                if (led === pattern)
                    on_count = on_count + 1;

                else if (led === 4'b0000)
                    off_count = off_count + 1;

                else
                    stop_error("Unexpected LED pattern while blinking");

                if (led !== prev_led) begin

                    if (last_change >= 0 &&
                        i-last_change != BLINK_HALF_CYCLES)
                        stop_error("Incorrect blink half-period");

                    last_change = i;
                    prev_led = led;
                    transitions = transitions + 1;
                end
            end

            if (on_count == 0 || off_count == 0 || transitions < 3)
                stop_error("Blinking not observed");
        end
    endtask

    // Execute one LED test case
    task run_case;
        input integer case_no;
        input [3:0] data_value;
        input [3:0] ctrl_value;
        input [3:0] expected_led;
        input is_blink;

        integer i;

        begin
            current_case_number = case_no;
            current_led_data = data_value;
            current_led_ctrl = ctrl_value;

            // Disable previous output
            axi_write(4'h4, 32'h0);

            // Write LED_DATA
            axi_write(4'h0, {28'b0, data_value});

            // Write LED_CTRL
            axi_write(4'h4, {28'b0, ctrl_value});

            // Verify register contents
            axi_read(4'h0, {28'b0, data_value});
            axi_read(4'h4, {28'b0, ctrl_value});

            if (is_blink) begin

                check_blink(data_value);

            end else begin

                repeat (2) @(posedge clk);
                #1;

                if (led !== expected_led) begin

                    $display("LED mismatch expected=%b got=%b",
                             expected_led, led);

                    stop_error("Incorrect steady LED state");
                end

                repeat (BLINK_HALF_CYCLES*2) begin

                    @(posedge clk);
                    #1;

                    if (led !== expected_led)
                        stop_error("Unexpected LED transition");
                end
            end

            passed_cases = passed_cases + 1;

            $display("[CASE %0d PASS] DATA=%b CTRL=%b",
                     case_no, data_value, ctrl_value);
        end
    endtask

    // Main simulation sequence
    initial begin

        resetn = 1'b0;

        s_axi_awaddr = 0;
        s_axi_awprot = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;

        s_axi_araddr = 0;
        s_axi_arprot = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;

        current_case_number = 0;
        current_led_data = 0;
        current_led_ctrl = 0;

        transactions = 0;
        passed_cases = 0;

        // Reset
        repeat (5) @(posedge clk);
        #1;

        if (led !== 4'b0000)
            stop_error("Reset must turn LEDs off");

        @(negedge clk);
        resetn = 1'b1;

        repeat (2) @(posedge clk);

        // CASE 1: LED OFF
        run_case(1, 4'b0000, 4'b0000, 4'b0000, 1'b0);

        // CASE 2: LED = 0101
        run_case(2, 4'b0101, 4'b0001, 4'b0101, 1'b0);

        // CASE 3: DATA=1011, CTRL=0010, LED OFF
        run_case(3, 4'b1011, 4'b0010, 4'b0000, 1'b0);

        // CASE 4: LED 1010 blinking
        run_case(4, 4'b1010, 4'b0011, 4'b0000, 1'b1);

        // CASE 5: All LEDs ON
        run_case(5, 4'b1111, 4'b0001, 4'b1111, 1'b0);

        // CASE 6: All LEDs OFF
        run_case(6, 4'b1111, 4'b0000, 4'b0000, 1'b0);

        if (passed_cases == 6) begin

            $display("ALL 6 CASES PASSED");
            $display("Total AXI transactions: %0d", transactions);

        end else
            stop_error("Not all cases passed");

        $finish;
    end

    // Global timeout
    initial begin
        #100000;
        stop_error("Global simulation timeout");
    end

endmodule

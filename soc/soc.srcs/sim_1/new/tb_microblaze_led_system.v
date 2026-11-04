
`timescale 1ns / 1ps
//==============================================================================
// tb_axi_led_system.sv
// AXI4-Lite LED peripheral testbench - 6 cases matched to main_led_test_6_cases.c
//
// AXI master BFM -> axi_lite_slave_v1_0 -> led_reg_bridge -> led_controller
//
// The MicroBlaze, SmartConnect, MMCM and board pins are deliberately excluded:
// this directly tests the memory-mapped LED peripheral at the AXI-Slave boundary.
// Simulated clock: 100 MHz. HALF_PERIOD=4 shortens LED blink ONLY in simulation.
//
// Original AXI register map:
//   0x00 LED_DATA    [3:0]
//   0x04 LED_CONTROL [0] enable, [1] blink_mode
//   Only offsets 0x00 and 0x04 are accessed in these 6 tests.
//==============================================================================
module tb_axi_led_system;
    localparam integer CLK_HALF_NS = 5;
    localparam integer BLINK_HALF_CYCLES = 4;
    localparam integer MAX_WAIT = 60;

    reg clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;
    reg resetn = 1'b0;

    // AXI4-Lite Master stimulus
    reg  [3:0]  s_axi_awaddr  = 4'h0;
    reg  [2:0]  s_axi_awprot  = 3'b000;
    reg         s_axi_awvalid = 1'b0;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata   = 32'h0;
    reg  [3:0]  s_axi_wstrb   = 4'h0;
    reg         s_axi_wvalid  = 1'b0;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready  = 1'b0;
    reg  [3:0]  s_axi_araddr  = 4'h0;
    reg  [2:0]  s_axi_arprot  = 3'b000;
    reg         s_axi_arvalid = 1'b0;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready  = 1'b0;

    // General-purpose interface exactly as in user's AXI source.
    wire        gp_write, gp_read;
    wire [5:0]  gp_write_addrs, gp_read_addrs;
    wire [31:0] gp_write_data, gp_read_data;
    wire [3:0]  gp_write_strobe;
    wire        gp_write_done, gp_write_error;
    wire        gp_read_done, gp_read_error;

    wire [3:0] led_data;
    wire       enable, blink_mode;
    wire [3:0] led;

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

    integer checks = 0;
    integer transactions = 0;

    task automatic fail(input string message);
        begin
            $display("[FAIL] t=%0t  %s", $time, message);
            $fatal(1, "TEST FAILED");
        end
    endtask

    task automatic check_led(input [3:0] expected, input string label);
        begin
            #1;
            checks = checks + 1;
            if (led !== expected)
                fail($sformatf("%s: LED expected %b, received %b", label, expected, led));
            $display("[PASS] %s | led=%b", label, led);
        end
    endtask

    // AW and W are separate AXI channels. Their arrival orders are varied.
    // BREADY is held low until both handshakes finish, preventing loss of a
    // zero-latency response when this particular open-source slave is used.
    task automatic axi_write(
        input [3:0] addr,
        input [31:0] data,
        input [3:0] strb,
        input integer aw_delay,
        input integer w_delay,
        input integer b_stall
    );
        begin
            @(negedge clk);
            s_axi_bready = 1'b0;
            fork
                begin : aw_path
                    integer count_aw;
                    count_aw = 0;
                    repeat (aw_delay) @(negedge clk);
                    s_axi_awaddr  = addr;
                    s_axi_awvalid = 1'b1;
                    begin : aw_handshake
                        forever begin
                            @(posedge clk);
                            if (s_axi_awready === 1'b1)
                                disable aw_handshake;
                            count_aw = count_aw + 1;
                            if (count_aw > MAX_WAIT)
                                fail($sformatf("AWREADY timeout at 0x%h",addr));
                        end
                    end
                    @(negedge clk);
                    s_axi_awvalid = 1'b0;
                end
                begin : w_path
                    integer count_w;
                    count_w = 0;
                    repeat (w_delay) @(negedge clk);
                    s_axi_wdata  = data;
                    s_axi_wstrb  = strb;
                    s_axi_wvalid = 1'b1;
                    begin : w_handshake
                        forever begin
                            @(posedge clk);
                            if (s_axi_wready === 1'b1)
                                disable w_handshake;
                            count_w = count_w + 1;
                            if (count_w > MAX_WAIT)
                                fail($sformatf("WREADY timeout at 0x%h",addr));
                        end
                    end
                    @(negedge clk);
                    s_axi_wvalid = 1'b0;
                end
            join

            // Check that BVALID and its response remain available under stall.
            @(negedge clk);
            if (s_axi_bvalid !== 1'b1 || s_axi_bresp !== 2'b00)
                fail($sformatf("No OKAY BRESP for write 0x%h: BVALID=%b BRESP=%b",
                                addr, s_axi_bvalid, s_axi_bresp));
            repeat (b_stall) begin
                @(posedge clk);
                #1;
                if (s_axi_bvalid !== 1'b1 || s_axi_bresp !== 2'b00)
                    fail("BVALID/BRESP changed while BREADY=0");
            end
            @(negedge clk);
            s_axi_bready = 1'b1;
            @(posedge clk);
            if (s_axi_bvalid !== 1'b1 || s_axi_bresp !== 2'b00)
                fail("BRESP handshake not OKAY");
            @(negedge clk);
            s_axi_bready = 1'b0;
            #1;
            if (s_axi_bvalid !== 1'b0)
                fail("BVALID remained asserted after accepted response");
            transactions = transactions + 1;
            $display("[WRITE OK] addr=0x%h data=0x%08h strobe=%b AWlag=%0d Wlag=%0d",
                      addr, data, strb, aw_delay, w_delay);
        end
    endtask

    task automatic axi_read(
        input [3:0] addr,
        input [31:0] expected,
        input integer r_stall
    );
        integer n;
        begin
            @(negedge clk);
            s_axi_rready  = 1'b0;
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;
            n = 0;
            begin : ar_handshake
                forever begin
                    @(posedge clk);
                    if (s_axi_arready === 1'b1)
                        disable ar_handshake;
                    n = n + 1;
                    if (n > MAX_WAIT)
                        fail($sformatf("ARREADY timeout at address 0x%h",addr));
                end
            end
            @(negedge clk);
            s_axi_arvalid = 1'b0;
            #1;
            if (s_axi_rvalid !== 1'b1)
                fail($sformatf("No RVALID for address 0x%h",addr));
            if (s_axi_rresp !== 2'b00 || s_axi_rdata !== expected)
                fail($sformatf("Read mismatch at 0x%h: expected 0x%08h, got 0x%08h RRESP=%b",
                                addr, expected, s_axi_rdata, s_axi_rresp));
            repeat (r_stall) begin
                @(posedge clk);
                #1;
                if (s_axi_rvalid !== 1'b1 || s_axi_rdata !== expected || s_axi_rresp !== 2'b00)
                    fail($sformatf("RDATA/RRESP changed under backpressure at 0x%h",addr));
            end
            @(negedge clk);
            s_axi_rready = 1'b1;
            @(posedge clk);
            if (s_axi_rvalid !== 1'b1 || s_axi_rdata !== expected || s_axi_rresp !== 2'b00)
                fail($sformatf("Read response changed at handshake: 0x%h",addr));
            @(negedge clk);
            s_axi_rready = 1'b0;
            #1;
            if (s_axi_rvalid !== 1'b0)
                fail("RVALID remained asserted after accepted response");
            transactions = transactions + 1;
            checks = checks + 1;
            $display("[READ PASS] addr=0x%h data=0x%08h R-stall=%0d",addr,expected,r_stall);
        end
    endtask


    // Visible in Vivado's waveform window to identify which C test case
    // is currently being reproduced at the AXI4-Lite slave interface.
    integer current_case_number = 0;
    reg [3:0] current_led_data = 4'b0000;
    reg [3:0] current_led_ctrl = 4'b0000;
    integer passed_cases = 0;

    // Check that a blinking LED toggles between the selected data and 0000,
    // with changes spaced BLINK_HALF_CYCLES simulation clock cycles apart.
    task automatic check_blink(input [3:0] pattern);
        integer k;
        integer saw_on;
        integer saw_off;
        integer last_change;
        integer transition_count;
        reg [3:0] previous_led;
        begin
            saw_on = 0;
            saw_off = 0;
            last_change = -1;
            transition_count = 0;
            previous_led = led;

            for (k = 0; k < BLINK_HALF_CYCLES * 8; k = k + 1) begin
                @(posedge clk);
                #1;
                if (led === pattern)
                    saw_on = saw_on + 1;
                else if (led === 4'b0000)
                    saw_off = saw_off + 1;
                else
                    fail($sformatf("Case 4: invalid blink value led=%b",led));

                if (led !== previous_led) begin
                    if ((last_change >= 0) &&
                        ((k - last_change) != BLINK_HALF_CYCLES))
                        fail($sformatf("Case 4: blink half period expected %0d clocks, got %0d clocks",
                                        BLINK_HALF_CYCLES, k-last_change));
                    last_change = k;
                    transition_count = transition_count + 1;
                    previous_led = led;
                end
            end
            if ((saw_on == 0) || (saw_off == 0) || (transition_count < 3))
                fail("Case 4: blink output did not alternate 1010/0000");

            checks = checks + 1;
            $display("[PASS] Case 4 blink: %b <-> 0000; transitions=%0d ON=%0d OFF=%0d",
                     pattern,transition_count,saw_on,saw_off);
        end
    endtask

    // A direct AXI master BFM reproduces the memory-mapped writes in main.c.
    // It does NOT execute the C program or MicroBlaze ELF.
    // For each case: CTRL=0 -> write DATA -> write CTRL -> read back both.
    task automatic run_case(
        input integer case_number,
        input [3:0] data,
        input [3:0] ctrl,
        input [3:0] expected_led,
        input bit expect_blink
    );
        begin
            current_case_number = case_number;
            current_led_data = data;
            current_led_ctrl = ctrl;

            $display("\n========= CASE %0d: DATA=%b CTRL=%b =========",
                     case_number, data, ctrl);

            // Disable the outputs before loading the next pattern, matching C.
            axi_write(4'h4, 32'h0000_0000, 4'b0001, 0, 0, 0);
            axi_write(4'h0, {28'h0,data}, 4'b0001, 0, 0, 0);
            axi_write(4'h4, {28'h0,ctrl}, 4'b0001, 0, 0, 0);

            axi_read(4'h0, {28'h0,data}, 0);
            axi_read(4'h4, {28'h0,ctrl}, 0);

            if (expect_blink)
                check_blink(data);
            else begin
                repeat (2) @(posedge clk);
                check_led(expected_led,
                          $sformatf("CASE %0d DATA=%b CTRL=%b",case_number,data,ctrl));
                // Verify the static value holds for several more clocks.
                repeat (BLINK_HALF_CYCLES * 2) begin
                    @(posedge clk);
                    #1;
                    if (led !== expected_led)
                        fail($sformatf("Case %0d: LED unexpectedly changed: got=%b expected=%b",
                                       case_number,led,expected_led));
                end
                checks = checks + 1;
            end

            passed_cases = passed_cases + 1;
            $display("[CASE %0d PASS] LED_DATA=%b LED_CTRL=%b",
                     case_number,data,ctrl);
        end
    endtask

    initial begin : test_sequence
        $display("\n===============================================================");
        $display("AXI4-Lite LED Controller: SIX specified software test cases");
        $display("Clock=100 MHz, blink HALF_PERIOD=%0d cycles (simulation only)",
                 BLINK_HALF_CYCLES);
        $display("===============================================================\n");
`ifdef IVERILOG
        $dumpfile("tb_axi_led_6_cases.vcd");
        $dumpvars(0,tb_axi_led_system);
`endif
        // Hardware initialization, not counted as an additional test case.
        repeat (5) @(posedge clk);
        #1;
        check_led(4'b0000,"LED off during hardware reset");
        @(negedge clk);
        resetn = 1'b1;
        repeat (2) @(posedge clk);

        // CASE  DATA  CTRL  EXPECTED LED
        // 1     0000  0000  0000 (off)
        // 2     0101  0001  0101 (steady)
        // 3     1011  0010  0000 (enable=0, blink_mode=1)
        // 4     1010  0011  1010 / 0000 (blink)
        // 5     1111  0001  1111 (all on)
        // 6     1111  0000  0000 (disabled with DATA=1111)
        run_case(1,4'b0000,4'b0000,4'b0000,1'b0);
        run_case(2,4'b0101,4'b0001,4'b0101,1'b0);
        run_case(3,4'b1011,4'b0010,4'b0000,1'b0);
        run_case(4,4'b1010,4'b0011,4'b0000,1'b1);
        run_case(5,4'b1111,4'b0001,4'b1111,1'b0);
        run_case(6,4'b1111,4'b0000,4'b0000,1'b0);

        if (passed_cases != 6)
            fail($sformatf("Expected 6 passing cases, got %0d",passed_cases));

        $display("\n===============================================================");
        $display("ALL 6 CASES PASSED: %0d AXI transactions; %0d checks",
                 transactions, checks);
        $display("===============================================================\n");
        $finish;
    end

    initial begin
        #100000;
        fail("GLOBAL TIMEOUT: simulation is stuck");
    end
endmodule

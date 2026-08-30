`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/30/2026 05:06:02 PM
// Design Name: 
// Module Name: top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module top_tb;

parameter DATA_WIDTH = 8;
parameter ADDR_WIDTH = 4;

// =====================================================
// CLOCK AND RESET
// =====================================================

reg clk;
reg rst_n;

// =====================================================
// PORT A
// =====================================================

reg [ADDR_WIDTH-1:0] addr_a;
reg [DATA_WIDTH-1:0] din_a;
reg we_a;
reg re_a;
wire [DATA_WIDTH-1:0] dout_a;

// =====================================================
// PORT B
// =====================================================

reg [ADDR_WIDTH-1:0] addr_b;
reg [DATA_WIDTH-1:0] din_b;
reg we_b;
reg re_b;
wire [DATA_WIDTH-1:0] dout_b;

// =====================================================
// BIST
// =====================================================

reg bist_start;
wire bist_busy;
wire bist_done;
wire bist_pass;

// =====================================================
// ERROR AND COLLISION STATUS
// =====================================================

wire collision;
wire corrected_error;
wire uncorrectable_error;

// =====================================================
// LOW POWER
// =====================================================

reg low_power_mode;
wire low_power_active;

// =====================================================
// TEST COUNTERS
// =====================================================

integer pass_count;
integer fail_count;


// =====================================================
// DUT
// =====================================================

top #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
)
dut (

    .clk(clk),
    .rst_n(rst_n),

    // Port A
    .addr_a(addr_a),
    .din_a(din_a),
    .we_a(we_a),
    .re_a(re_a),
    .dout_a(dout_a),

    // Port B
    .addr_b(addr_b),
    .din_b(din_b),
    .we_b(we_b),
    .re_b(re_b),
    .dout_b(dout_b),

    // BIST
    .bist_start(bist_start),
    .bist_busy(bist_busy),
    .bist_done(bist_done),
    .bist_pass(bist_pass),

    // Status
    .collision(collision),
    .corrected_error(corrected_error),
    .uncorrectable_error(uncorrectable_error),

    // Low Power
    .low_power_mode(low_power_mode),
    .low_power_active(low_power_active)

);


// =====================================================
// CLOCK
// =====================================================

initial begin
    clk = 1'b0;
end

always #5 clk = ~clk;


// =====================================================
// CHECK DATA
// =====================================================

task check_data;

input [DATA_WIDTH-1:0] actual;
input [DATA_WIDTH-1:0] expected;

begin

    if(actual === expected) begin

        $display("[PASS] DATA  Expected=%h Actual=%h",
                 expected, actual);

        pass_count = pass_count + 1;

    end

    else begin

        $display("[FAIL] DATA  Expected=%h Actual=%h",
                 expected, actual);

        fail_count = fail_count + 1;

    end

end

endtask


// =====================================================
// CHECK BIT
// =====================================================

task check_bit;

input actual;
input expected;

begin

    if(actual === expected) begin

        $display("[PASS] BIT   Expected=%b Actual=%b",
                 expected, actual);

        pass_count = pass_count + 1;

    end

    else begin

        $display("[FAIL] BIT   Expected=%b Actual=%b",
                 expected, actual);

        fail_count = fail_count + 1;

    end

end

endtask


// =====================================================
// WRITE PORT A
// =====================================================

task write_a;

input [ADDR_WIDTH-1:0] addr;
input [DATA_WIDTH-1:0] data;

begin

    @(negedge clk);

    addr_a = addr;
    din_a  = data;
    we_a   = 1'b1;

    @(negedge clk);

    we_a = 1'b0;

end

endtask


// =====================================================
// READ PORT A
// =====================================================

task read_a;

input [ADDR_WIDTH-1:0] addr;
input [DATA_WIDTH-1:0] expected;

begin

    @(negedge clk);

    addr_a = addr;
    re_a   = 1'b1;

    @(posedge clk);

    #1;

    check_data(dout_a, expected);

    @(negedge clk);

    re_a = 1'b0;

end

endtask


// =====================================================
// WRITE PORT B
// =====================================================

task write_b;

input [ADDR_WIDTH-1:0] addr;
input [DATA_WIDTH-1:0] data;

begin

    @(negedge clk);

    addr_b = addr;
    din_b  = data;
    we_b   = 1'b1;

    @(negedge clk);

    we_b = 1'b0;

end

endtask


// =====================================================
// READ PORT B
// =====================================================

task read_b;

input [ADDR_WIDTH-1:0] addr;
input [DATA_WIDTH-1:0] expected;

begin

    @(negedge clk);

    addr_b = addr;
    re_b   = 1'b1;

    @(posedge clk);

    #1;

    check_data(dout_b, expected);

    @(negedge clk);

    re_b = 1'b0;

end

endtask


// =====================================================
// MAIN TEST
// =====================================================

initial begin

    pass_count = 0;
    fail_count = 0;

    // -------------------------------------------------
    // INITIAL VALUES
    // -------------------------------------------------

    rst_n = 1'b0;

    addr_a = 0;
    addr_b = 0;

    din_a = 0;
    din_b = 0;

    we_a = 0;
    we_b = 0;

    re_a = 0;
    re_b = 0;

    bist_start = 0;

    low_power_mode = 0;


    // -------------------------------------------------
    // RESET
    // -------------------------------------------------

    repeat(2)
        @(posedge clk);

    rst_n = 1'b1;

    #2;


    // =================================================
    // TEST 1 : BASIC PORT A
    // =================================================

    $display("\n========================================");
    $display("TEST 1 : BASIC PORT A");
    $display("========================================");

    write_a(4'h2, 8'hA5);

    read_a(4'h2, 8'hA5);


    // =================================================
    // TEST 2 : BASIC PORT B
    // =================================================

    $display("\n========================================");
    $display("TEST 2 : BASIC PORT B");
    $display("========================================");

    write_b(4'h5, 8'h3C);

    read_b(4'h5, 8'h3C);


    // =================================================
    // TEST 3 : DUAL PORT OPERATION
    // =================================================

    $display("\n========================================");
    $display("TEST 3 : DUAL PORT OPERATION");
    $display("========================================");

    @(negedge clk);

    addr_a = 4'h6;
    din_a  = 8'h55;
    we_a   = 1'b1;

    addr_b = 4'h7;
    din_b  = 8'hAA;
    we_b   = 1'b1;

    @(negedge clk);

    we_a = 1'b0;
    we_b = 1'b0;

    read_a(4'h6, 8'h55);

    read_b(4'h7, 8'hAA);


    // =================================================
    // TEST 4 : COLLISION
    // =================================================

    $display("\n========================================");
    $display("TEST 4 : COLLISION DETECTION");
    $display("========================================");

    @(negedge clk);

    addr_a = 4'h8;
    din_a  = 8'hF0;
    we_a   = 1'b1;

    addr_b = 4'h8;
    din_b  = 8'h0F;
    we_b   = 1'b1;

    @(posedge clk);

    #1;

    check_bit(collision, 1'b1);

    @(negedge clk);

    we_a = 1'b0;
    we_b = 1'b0;

    // Port A has priority
    read_a(4'h8, 8'hF0);


    // =================================================
    // TEST 5 : BIST
    // =================================================

    $display("\n========================================");
    $display("TEST 5 : BIST");
    $display("========================================");

    @(negedge clk);

    bist_start = 1'b1;

    @(negedge clk);

    bist_start = 1'b0;

    wait(bist_done == 1'b1);

    #1;

    check_bit(bist_pass, 1'b1);

    $display("BIST BUSY = %b", bist_busy);
    $display("BIST DONE = %b", bist_done);
    $display("BIST PASS = %b", bist_pass);


    // =================================================
    // TEST 6 : ECC SINGLE BIT ERROR
    // =================================================

    $display("\n========================================");
    $display("TEST 6 : ECC SINGLE BIT ERROR");
    $display("========================================");

    write_a(4'h3, 8'h5A);

    // Inject one bit error
    dut.mem[4'h3][0] = ~dut.mem[4'h3][0];

    @(negedge clk);

    addr_a = 4'h3;
    re_a   = 1'b1;

    @(posedge clk);

    #1;

    check_data(dout_a, 8'h5A);

    check_bit(corrected_error, 1'b1);

    @(negedge clk);

    re_a = 1'b0;


    // =================================================
    // TEST 7 : ECC DOUBLE BIT ERROR
    // =================================================

    $display("\n========================================");
    $display("TEST 7 : ECC DOUBLE BIT ERROR");
    $display("========================================");

    write_a(4'h4, 8'hC3);

    // Inject two bit errors
    dut.mem[4'h4][0] = ~dut.mem[4'h4][0];
    dut.mem[4'h4][1] = ~dut.mem[4'h4][1];

    @(negedge clk);

    addr_a = 4'h4;
    re_a   = 1'b1;

    @(posedge clk);

    #1;

    check_bit(uncorrectable_error, 1'b1);

    @(negedge clk);

    re_a = 1'b0;


    // =================================================
    // TEST 8 : LOW POWER MODE
    // =================================================

    $display("\n========================================");
    $display("TEST 8 : LOW POWER MODE");
    $display("========================================");


    // First store known data
    write_a(4'h9, 8'h5A);

    // Verify data before entering low power
    read_a(4'h9, 8'h5A);


    // Enter low power mode
    $display("Entering Low Power Mode...");

    @(negedge clk);

    low_power_mode = 1'b1;

    @(posedge clk);

    #1;

    check_bit(low_power_active, 1'b1);

    $display("LOW POWER ACTIVE = %b",
             low_power_active);


    // Keep low power mode active
    repeat(3)
        @(posedge clk);

    #1;

    check_bit(low_power_active, 1'b1);


    // Exit low power mode
    $display("Exiting Low Power Mode...");

    @(negedge clk);

    low_power_mode = 1'b0;

    @(posedge clk);

    #1;

    check_bit(low_power_active, 1'b0);


    // Check memory retention
    // Data should still be 5A
    read_a(4'h9, 8'h5A);


    // =================================================
    // FINAL RESULT
    // =================================================

    #20;

    $display("\n========================================");
    $display("SIMULATION COMPLETE");
    $display("========================================");

    $display("PASS COUNT = %0d", pass_count);
    $display("FAIL COUNT = %0d", fail_count);

    if(fail_count == 0)
        $display("RESULT : ALL TESTS PASSED");
    else
        $display("RESULT : SOME TESTS FAILED");

    $finish;

end

endmodule

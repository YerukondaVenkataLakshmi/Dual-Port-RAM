`timescale 1ns/1ps

module dualport_tb;

parameter DATA_WIDTH=8;
parameter ADDR_WIDTH=4;

reg clk;
reg rst_n;

reg [ADDR_WIDTH-1:0] addr_a;
reg [DATA_WIDTH-1:0] din_a;
reg we_a;
reg re_a;
wire [DATA_WIDTH-1:0] dout_a;

reg [ADDR_WIDTH-1:0] addr_b;
reg [DATA_WIDTH-1:0] din_b;
reg we_b;
reg re_b;
wire [DATA_WIDTH-1:0] dout_b;

reg bist_start;
wire bist_busy;
wire bist_done;
wire bist_pass;

wire collision;
wire corrected_error;
wire uncorrectable_error;

integer pass_count;
integer fail_count;

top #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
)
dut (
    .clk(clk),
    .rst_n(rst_n),
    .addr_a(addr_a),
    .din_a(din_a),
    .we_a(we_a),
    .re_a(re_a),
    .dout_a(dout_a),
    .addr_b(addr_b),
    .din_b(din_b),
    .we_b(we_b),
    .re_b(re_b),
    .dout_b(dout_b),
    .bist_start(bist_start),
    .bist_busy(bist_busy),
    .bist_done(bist_done),
    .bist_pass(bist_pass),
    .collision(collision),
    .corrected_error(corrected_error),
    .uncorrectable_error(uncorrectable_error)
);

initial clk=0;
always #5 clk=~clk;

task check_data;
input [DATA_WIDTH-1:0] actual;
input [DATA_WIDTH-1:0] expected;
begin
    if(actual===expected) begin
        $display("[PASS] Expected=%h Actual=%h",expected,actual);
        pass_count=pass_count+1;
    end
    else begin
        $display("[FAIL] Expected=%h Actual=%h",expected,actual);
        fail_count=fail_count+1;
    end
end
endtask

task check_bit;
input actual;
input expected;
begin
    if(actual===expected) begin
        $display("[PASS] Expected=%b Actual=%b",expected,actual);
        pass_count=pass_count+1;
    end
    else begin
        $display("[FAIL] Expected=%b Actual=%b",expected,actual);
        fail_count=fail_count+1;
    end
end
endtask

task write_a;
input [ADDR_WIDTH-1:0] addr;
input [DATA_WIDTH-1:0] data;
begin
    @(negedge clk);
    addr_a=addr;
    din_a=data;
    we_a=1;

    @(negedge clk);
    we_a=0;
end
endtask

task read_a;
input [ADDR_WIDTH-1:0] addr;
input [DATA_WIDTH-1:0] expected;
begin
    @(negedge clk);
    addr_a=addr;
    re_a=1;

    @(posedge clk);
    #1;
    check_data(dout_a,expected);

    @(negedge clk);
    re_a=0;
end
endtask

task write_b;
input [ADDR_WIDTH-1:0] addr;
input [DATA_WIDTH-1:0] data;
begin
    @(negedge clk);
    addr_b=addr;
    din_b=data;
    we_b=1;

    @(negedge clk);
    we_b=0;
end
endtask

task read_b;
input [ADDR_WIDTH-1:0] addr;
input [DATA_WIDTH-1:0] expected;
begin
    @(negedge clk);
    addr_b=addr;
    re_b=1;

    @(posedge clk);
    #1;
    check_data(dout_b,expected);

    @(negedge clk);
    re_b=0;
end
endtask

initial begin

    pass_count=0;
    fail_count=0;

    rst_n=0;

    addr_a=0;
    addr_b=0;
    din_a=0;
    din_b=0;

    we_a=0;
    we_b=0;
    re_a=0;
    re_b=0;

    bist_start=0;

    repeat(2)
        @(posedge clk);

    rst_n=1;

    $display("\nTEST 1 : BASIC PORT A");

    write_a(4'h2,8'hA5);
    read_a(4'h2,8'hA5);

    $display("\nTEST 2 : BASIC PORT B");

    write_b(4'h5,8'h3C);
    read_b(4'h5,8'h3C);

    $display("\nTEST 3 : DUAL PORT");

    @(negedge clk);

    addr_a=4'h6;
    din_a=8'h55;
    we_a=1;

    addr_b=4'h7;
    din_b=8'hAA;
    we_b=1;

    @(negedge clk);

    we_a=0;
    we_b=0;

    read_a(4'h6,8'h55);
    read_b(4'h7,8'hAA);

    $display("\nTEST 4 : COLLISION");

    @(negedge clk);

    addr_a=4'h8;
    din_a=8'hF0;
    we_a=1;

    addr_b=4'h8;
    din_b=8'h0F;
    we_b=1;

    @(posedge clk);
    #1;

    check_bit(collision,1);

    @(negedge clk);

    we_a=0;
    we_b=0;

    read_a(4'h8,8'hF0);

    $display("\nTEST 5 : BIST");

    @(negedge clk);

    bist_start=1;

    @(negedge clk);

    bist_start=0;

    wait(bist_done==1);

    #1;

    check_bit(bist_pass,1);

    $display("\nTEST 6 : ECC SINGLE BIT");

    write_a(4'h3,8'h5A);

    dut.mem[4'h3][0]=~dut.mem[4'h3][0];

    @(negedge clk);

    addr_a=4'h3;
    re_a=1;

    @(posedge clk);
    #1;

    check_data(dout_a,8'h5A);
    check_bit(corrected_error,1);

    @(negedge clk);

    re_a=0;

    $display("\nTEST 7 : ECC DOUBLE BIT");

    write_a(4'h4,8'hC3);

    dut.mem[4'h4][0]=~dut.mem[4'h4][0];
    dut.mem[4'h4][1]=~dut.mem[4'h4][1];

    @(negedge clk);

    addr_a=4'h4;
    re_a=1;

    @(posedge clk);
    #1;

    check_bit(uncorrectable_error,1);

    @(negedge clk);

    re_a=0;

    #20;
    $display("SIMULATION COMPLETE");
    $display("PASS COUNT = %0d",pass_count);
    $display("FAIL COUNT = %0d",fail_count);
    if(fail_count==0)
        $display("RESULT : ALL TESTS PASSED");
    else
        $display("RESULT : SOME TESTS FAILED");

    $finish;

end

endmodule

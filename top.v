`timescale 1ns/1ps

module top #(
    parameter DATA_WIDTH=8,
    parameter ADDR_WIDTH=4,
    parameter ECC_BITS=4,
    parameter CODE_WIDTH=DATA_WIDTH+ECC_BITS+1,
    parameter DEPTH=(1<<ADDR_WIDTH)
)(
    input clk,
    input rst_n,

    // Port A
    input [ADDR_WIDTH-1:0] addr_a,
    input [DATA_WIDTH-1:0] din_a,
    input we_a,
    input re_a,
    output reg [DATA_WIDTH-1:0] dout_a,

    // Port B
    input [ADDR_WIDTH-1:0] addr_b,
    input [DATA_WIDTH-1:0] din_b,
    input we_b,
    input re_b,
    output reg [DATA_WIDTH-1:0] dout_b,

    // BIST
    input bist_start,
    output reg bist_busy,
    output reg bist_done,
    output reg bist_pass,

    // Error and collision status
    output reg collision,
    output reg corrected_error,
    output reg uncorrectable_error,

    // Low Power Mode
    input low_power_mode,
    output reg low_power_active
);

reg [CODE_WIDTH-1:0] mem [0:DEPTH-1];

localparam B_IDLE  = 3'b000;
localparam B_WRITE0 = 3'b001;
localparam B_R0W1  = 3'b010;
localparam B_R1W0  = 3'b011;
localparam B_READ0 = 3'b100;

reg [2:0] bist_state;
reg [ADDR_WIDTH-1:0] bist_addr;
reg bist_error;

reg [DATA_WIDTH-1:0] decoded_data_a;
reg [DATA_WIDTH-1:0] decoded_data_b;

reg decoded_corr_a;
reg decoded_corr_b;

reg decoded_uncorr_a;
reg decoded_uncorr_b;


// ============================================================
// ECC ENCODER
// ============================================================

function [CODE_WIDTH-1:0] ecc_encode;

input [DATA_WIDTH-1:0] data;

reg [CODE_WIDTH-1:0] codeword;
reg parity;

integer pos;
integer data_index;
integer p;

begin

    codeword = {CODE_WIDTH{1'b0}};
    data_index = 0;

    // Place data bits in non-power-of-two positions
    for(pos=1; pos<=DATA_WIDTH+ECC_BITS; pos=pos+1) begin

        if((pos & (pos-1)) != 0) begin

            codeword[pos-1] = data[data_index];
            data_index = data_index + 1;

        end

    end


    // Generate Hamming parity bits
    for(p=0; p<ECC_BITS; p=p+1) begin

        parity = 1'b0;

        for(pos=1; pos<=DATA_WIDTH+ECC_BITS; pos=pos+1) begin

            if((pos & (1<<p)) != 0)
                parity = parity ^ codeword[pos-1];

        end

        codeword[(1<<p)-1] = parity;

    end


    // Overall parity
    parity = 1'b0;

    for(pos=0; pos<DATA_WIDTH+ECC_BITS; pos=pos+1)
        parity = parity ^ codeword[pos];

    codeword[CODE_WIDTH-1] = parity;

    ecc_encode = codeword;

end

endfunction


// ============================================================
// ECC DECODER
// ============================================================

task ecc_decode;

input [CODE_WIDTH-1:0] codeword_in;

output [DATA_WIDTH-1:0] data_out;
output corr;
output uncorr;

reg [CODE_WIDTH-1:0] codeword;
reg parity;

integer syndrome;
integer pos;
integer p;
integer data_index;

begin

    codeword = codeword_in;
    syndrome = 0;


    // Calculate syndrome
    for(p=0; p<ECC_BITS; p=p+1) begin

        parity = 1'b0;

        for(pos=1; pos<=DATA_WIDTH+ECC_BITS; pos=pos+1) begin

            if((pos & (1<<p)) != 0)
                parity = parity ^ codeword[pos-1];

        end

        if(parity)
            syndrome = syndrome | (1<<p);

    end


    // Calculate overall parity
    parity = codeword[CODE_WIDTH-1];

    for(pos=0; pos<DATA_WIDTH+ECC_BITS; pos=pos+1)
        parity = parity ^ codeword[pos];


    corr = 1'b0;
    uncorr = 1'b0;


    // Single-bit error
    if((parity == 1'b1) && (syndrome != 0)) begin

        if(syndrome <= DATA_WIDTH+ECC_BITS) begin

            codeword[syndrome-1] = ~codeword[syndrome-1];
            corr = 1'b1;

        end
        else begin

            uncorr = 1'b1;

        end

    end


    // Error in overall parity bit
    else if((parity == 1'b1) && (syndrome == 0)) begin

        codeword[CODE_WIDTH-1] = ~codeword[CODE_WIDTH-1];
        corr = 1'b1;

    end


    // Double-bit error
    else if((parity == 1'b0) && (syndrome != 0)) begin

        uncorr = 1'b1;

    end


    // Extract original data
    data_out = {DATA_WIDTH{1'b0}};
    data_index = 0;

    for(pos=1; pos<=DATA_WIDTH+ECC_BITS; pos=pos+1) begin

        if((pos & (pos-1)) != 0) begin

            data_out[data_index] = codeword[pos-1];
            data_index = data_index + 1;

        end

    end

end

endtask


// ============================================================
// MAIN CONTROL
// ============================================================

always @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin

        dout_a <= {DATA_WIDTH{1'b0}};
        dout_b <= {DATA_WIDTH{1'b0}};

        bist_busy <= 1'b0;
        bist_done <= 1'b0;
        bist_pass <= 1'b0;

        collision <= 1'b0;
        corrected_error <= 1'b0;
        uncorrectable_error <= 1'b0;

        low_power_active <= 1'b0;

        bist_state <= B_IDLE;
        bist_addr <= {ADDR_WIDTH{1'b0}};
        bist_error <= 1'b0;

        decoded_data_a <= {DATA_WIDTH{1'b0}};
        decoded_data_b <= {DATA_WIDTH{1'b0}};

        decoded_corr_a <= 1'b0;
        decoded_corr_b <= 1'b0;

        decoded_uncorr_a <= 1'b0;
        decoded_uncorr_b <= 1'b0;

    end

    else begin

        // ====================================================
        // LOW POWER MODE
        // ====================================================

        if(low_power_mode) begin

            // Indicate that low-power mode is active
            low_power_active <= 1'b1;

            // Hold outputs and internal state.
            // No RAM read/write activity.
            // No BIST activity.
            // Existing memory contents are retained.

        end


        // ====================================================
        // NORMAL MODE
        // ====================================================

        else begin

            low_power_active <= 1'b0;

            bist_done <= 1'b0;
            collision <= 1'b0;
            corrected_error <= 1'b0;
            uncorrectable_error <= 1'b0;


            // =================================================
            // BIST START
            // =================================================

            if(bist_start && !bist_busy) begin

                bist_busy <= 1'b1;
                bist_done <= 1'b0;
                bist_pass <= 1'b1;
                bist_error <= 1'b0;

                bist_addr <= {ADDR_WIDTH{1'b0}};
                bist_state <= B_WRITE0;

            end


            // =================================================
            // BIST OPERATION
            // =================================================

            else if(bist_busy) begin

                case(bist_state)


                    // -----------------------------------------
                    // WRITE ZERO TO ALL LOCATIONS
                    // -----------------------------------------

                    B_WRITE0: begin

                        mem[bist_addr] <=
                            ecc_encode({DATA_WIDTH{1'b0}});

                        if(bist_addr == DEPTH-1) begin

                            bist_addr <= {ADDR_WIDTH{1'b0}};
                            bist_state <= B_R0W1;

                        end
                        else begin

                            bist_addr <= bist_addr + 1'b1;

                        end

                    end


                    // -----------------------------------------
                    // READ ZERO / WRITE ONE
                    // -----------------------------------------

                    B_R0W1: begin

                        ecc_decode(
                            mem[bist_addr],
                            decoded_data_a,
                            decoded_corr_a,
                            decoded_uncorr_a
                        );

                        if(decoded_uncorr_a ||
                           (decoded_data_a != {DATA_WIDTH{1'b0}}))
                            bist_error <= 1'b1;

                        mem[bist_addr] <=
                            ecc_encode({DATA_WIDTH{1'b1}});

                        if(bist_addr == DEPTH-1) begin

                            bist_addr <= {ADDR_WIDTH{1'b0}};
                            bist_state <= B_R1W0;

                        end
                        else begin

                            bist_addr <= bist_addr + 1'b1;

                        end

                    end


                    // -----------------------------------------
                    // READ ONE / WRITE ZERO
                    // -----------------------------------------

                    B_R1W0: begin

                        ecc_decode(
                            mem[bist_addr],
                            decoded_data_a,
                            decoded_corr_a,
                            decoded_uncorr_a
                        );

                        if(decoded_uncorr_a ||
                           (decoded_data_a != {DATA_WIDTH{1'b1}}))
                            bist_error <= 1'b1;

                        mem[bist_addr] <=
                            ecc_encode({DATA_WIDTH{1'b0}});

                        if(bist_addr == DEPTH-1) begin

                            bist_addr <= {ADDR_WIDTH{1'b0}};
                            bist_state <= B_READ0;

                        end
                        else begin

                            bist_addr <= bist_addr + 1'b1;

                        end

                    end


                    // -----------------------------------------
                    // FINAL READ ZERO
                    // -----------------------------------------

                    B_READ0: begin

                        ecc_decode(
                            mem[bist_addr],
                            decoded_data_a,
                            decoded_corr_a,
                            decoded_uncorr_a
                        );

                        if(decoded_uncorr_a ||
                           (decoded_data_a != {DATA_WIDTH{1'b0}}))
                            bist_error <= 1'b1;

                        if(bist_addr == DEPTH-1) begin

                            bist_busy <= 1'b0;
                            bist_done <= 1'b1;
                            bist_state <= B_IDLE;

                            bist_addr <= {ADDR_WIDTH{1'b0}};

                            if(bist_error ||
                               decoded_uncorr_a ||
                               (decoded_data_a != {DATA_WIDTH{1'b0}}))
                                bist_pass <= 1'b0;
                            else
                                bist_pass <= 1'b1;

                        end
                        else begin

                            bist_addr <= bist_addr + 1'b1;

                        end

                    end


                    default: begin

                        bist_state <= B_IDLE;
                        bist_busy <= 1'b0;
                        bist_done <= 1'b0;
                        bist_pass <= 1'b0;

                    end

                endcase

            end


            // =================================================
            // NORMAL DUAL-PORT OPERATION
            // =================================================

            else begin


                // ---------------------------------------------
                // COLLISION HANDLING
                // ---------------------------------------------

                if(we_a && we_b && (addr_a == addr_b)) begin

                    collision <= 1'b1;

                    // Port A has priority
                    mem[addr_a] <= ecc_encode(din_a);

                end

                else begin

                    if(we_a)
                        mem[addr_a] <= ecc_encode(din_a);

                    if(we_b)
                        mem[addr_b] <= ecc_encode(din_b);

                end


                // ---------------------------------------------
                // PORT A READ
                // ---------------------------------------------

                if(re_a) begin

                    ecc_decode(
                        mem[addr_a],
                        decoded_data_a,
                        decoded_corr_a,
                        decoded_uncorr_a
                    );

                    dout_a <= decoded_data_a;

                    if(decoded_corr_a)
                        corrected_error <= 1'b1;

                    if(decoded_uncorr_a)
                        uncorrectable_error <= 1'b1;

                end


                // ---------------------------------------------
                // PORT B READ
                // ---------------------------------------------

                if(re_b) begin

                    ecc_decode(
                        mem[addr_b],
                        decoded_data_b,
                        decoded_corr_b,
                        decoded_uncorr_b
                    );

                    dout_b <= decoded_data_b;

                    if(decoded_corr_b)
                        corrected_error <= 1'b1;

                    if(decoded_uncorr_b)
                        uncorrectable_error <= 1'b1;

                end

            end

        end

    end

end

endmodule

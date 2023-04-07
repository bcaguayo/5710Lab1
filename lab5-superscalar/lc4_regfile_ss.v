`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

   // wire [n-1:0] iwdata = (i_rd_A == i_rd_B) ? i_wdata_B;
   wire [n-1:0] default_w = 16'd0;

   wire [n-1:0] iwdata_0 = (i_rd_B == 3'b000 & i_rd_we_B) ? i_wdata_B :
                           (i_rd_A == 3'b000 & i_rd_we_A) ? i_wdata_A : default_w;
                         
   wire [n-1:0] iwdata_1 = (i_rd_B == 3'b001 & i_rd_we_B) ? i_wdata_B :
                           (i_rd_A == 3'b001 & i_rd_we_A) ? i_wdata_A : default_w;
   
   wire [n-1:0] iwdata_2 = (i_rd_B == 3'b010 & i_rd_we_B) ? i_wdata_B :
                           (i_rd_A == 3'b010 & i_rd_we_A) ? i_wdata_A : default_w;
   
   wire [n-1:0] iwdata_3 = (i_rd_B == 3'b011 & i_rd_we_B) ? i_wdata_B :
                           (i_rd_A == 3'b011 & i_rd_we_A) ? i_wdata_A : default_w;

   wire [n-1:0] iwdata_4 = (i_rd_B == 3'b100 & i_rd_we_B) ? i_wdata_B :
                           (i_rd_A == 3'b100 & i_rd_we_A) ? i_wdata_A : default_w;
                         
   wire [n-1:0] iwdata_5 = (i_rd_B == 3'b101 & i_rd_we_B) ? i_wdata_B :
                           (i_rd_A == 3'b101 & i_rd_we_A) ? i_wdata_A : default_w;
   
   wire [n-1:0] iwdata_6 = (i_rd_B == 3'b110 & i_rd_we_B) ? i_wdata_B :
                           (i_rd_A == 3'b110 & i_rd_we_A) ? i_wdata_A : default_w;
   
   wire [n-1:0] iwdata_7 = (i_rd_B == 3'b111 & i_rd_we_B) ? i_wdata_B :
                           (i_rd_A == 3'b111 & i_rd_we_A) ? i_wdata_A : default_w;
   
   // Register Values
   wire [n-1:0] r0v, r1v, r2v, r3v, r4v, r5v, r6v, r7v;

   wire we_0 = (i_rd_A == 3'b000 && i_rd_we_A) || (i_rd_B == 3'b000 && i_rd_we_B);
   wire we_1 = (i_rd_A == 3'b001 && i_rd_we_A) || (i_rd_B == 3'b001 && i_rd_we_B);
   wire we_2 = (i_rd_A == 3'b010 && i_rd_we_A) || (i_rd_B == 3'b010 && i_rd_we_B);
   wire we_3 = (i_rd_A == 3'b011 && i_rd_we_A) || (i_rd_B == 3'b011 && i_rd_we_B);
   wire we_4 = (i_rd_A == 3'b100 && i_rd_we_A) || (i_rd_B == 3'b100 && i_rd_we_B);
   wire we_5 = (i_rd_A == 3'b101 && i_rd_we_A) || (i_rd_B == 3'b101 && i_rd_we_B);
   wire we_6 = (i_rd_A == 3'b110 && i_rd_we_A) || (i_rd_B == 3'b110 && i_rd_we_B);
   wire we_7 = (i_rd_A == 3'b111 && i_rd_we_A) || (i_rd_B == 3'b111 && i_rd_we_B);

   Nbit_reg #(n) r0(.in(iwdata_0), .out(r0v), .clk(clk), .we(we_0), .gwe(gwe), .rst(rst));
   Nbit_reg #(n) r1(.in(iwdata_1), .out(r1v), .clk(clk), .we(we_1), .gwe(gwe), .rst(rst));
   Nbit_reg #(n) r2(.in(iwdata_2), .out(r2v), .clk(clk), .we(we_2), .gwe(gwe), .rst(rst));
   Nbit_reg #(n) r3(.in(iwdata_3), .out(r3v), .clk(clk), .we(we_3), .gwe(gwe), .rst(rst));
   Nbit_reg #(n) r4(.in(iwdata_4), .out(r4v), .clk(clk), .we(we_4), .gwe(gwe), .rst(rst));
   Nbit_reg #(n) r5(.in(iwdata_5), .out(r5v), .clk(clk), .we(we_5), .gwe(gwe), .rst(rst));
   Nbit_reg #(n) r6(.in(iwdata_6), .out(r6v), .clk(clk), .we(we_6), .gwe(gwe), .rst(rst));
   Nbit_reg #(n) r7(.in(iwdata_7), .out(r7v), .clk(clk), .we(we_7), .gwe(gwe), .rst(rst));

   assign o_rs_data_A = (i_rd_B == i_rs_A & i_rd_we_B) ? i_wdata_B :
                        (i_rd_A == i_rs_A & i_rd_we_A) ? i_wdata_A :
                        (i_rs_A == 3'b000) ? r0v : 
                        (i_rs_A == 3'b001) ? r1v : 
                        (i_rs_A == 3'b010) ? r2v : 
                        (i_rs_A == 3'b011) ? r3v : 
                        (i_rs_A == 3'b100) ? r4v : 
                        (i_rs_A == 3'b101) ? r5v : 
                        (i_rs_A == 3'b110) ? r6v : r7v;    

   assign o_rt_data_A = (i_rd_B == i_rt_A & i_rd_we_B) ? i_wdata_B :
                        (i_rd_A == i_rt_A & i_rd_we_A) ? i_wdata_A :
                        (i_rt_A == 3'b000) ? r0v : 
                        (i_rt_A == 3'b001) ? r1v : 
                        (i_rt_A == 3'b010) ? r2v : 
                        (i_rt_A == 3'b011) ? r3v : 
                        (i_rt_A == 3'b100) ? r4v : 
                        (i_rt_A == 3'b101) ? r5v : 
                        (i_rt_A == 3'b110) ? r6v : r7v; 

   assign o_rs_data_B = (i_rd_B == i_rs_B & i_rd_we_B) ? i_wdata_B :
                        (i_rd_A == i_rs_B & i_rd_we_A) ? i_wdata_A :
                        (i_rs_B == 3'b000) ? r0v : 
                        (i_rs_B == 3'b001) ? r1v : 
                        (i_rs_B == 3'b010) ? r2v : 
                        (i_rs_B == 3'b011) ? r3v : 
                        (i_rs_B == 3'b100) ? r4v : 
                        (i_rs_B == 3'b101) ? r5v : 
                        (i_rs_B == 3'b110) ? r6v : r7v;    

   assign o_rt_data_B = (i_rd_B == i_rt_B & i_rd_we_B) ? i_wdata_B :
                        (i_rd_A == i_rt_B & i_rd_we_A) ? i_wdata_A :
                        (i_rt_B == 3'b000) ? r0v : 
                        (i_rt_B == 3'b001) ? r1v : 
                        (i_rt_B == 3'b010) ? r2v : 
                        (i_rt_B == 3'b011) ? r3v : 
                        (i_rt_B == 3'b100) ? r4v : 
                        (i_rt_B == 3'b101) ? r5v : 
                        (i_rt_B == 3'b110) ? r6v : r7v; 

// output wire [n-1:0] o_rs_data_A
// output wire [n-1:0] o_rt_data_A

// output wire [n-1:0] o_rs_data_B
// output wire [n-1:0] o_rt_data_B

endmodule

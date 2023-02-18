/* TODO: Qiao Xu, Mili Soto
 * TODO: qiaoqiao, saguayo
 *
 * lc4_regfile.v
 * Implements an 8-register register file parameterized on word size.
 *
 */

`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_regfile #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,
    input  wire [  2:0] i_rs,      // rs selector
    output wire [n-1:0] o_rs_data, // rs contents
    input  wire [  2:0] i_rt,      // rt selector
    output wire [n-1:0] o_rt_data, // rt contents
    input  wire [  2:0] i_rd,      // rd selector
    input  wire [n-1:0] i_wdata,   // data to write
    input  wire         i_rd_we    // write enable
    );

    // Register Values
    wire [n-1:0] r0v, r1v, r2v, r3v, r4v, r5v, r6v, r7v;
    // (i_rd == 3'b000) & i_rd_we

    /*
    input  wire [n-1:0] in,
    output wire [n-1:0] out,
    input  wire         clk,
    input  wire         we,
    input  wire         gwe,
    input  wire         rst
    */

    Nbit_reg #(n) r0(.in(i_wdata), .out(r0v), .clk(clk), .we(i_rd == 3'b000 & i_rd_we == 1), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r1(.in(i_wdata), .out(r1v), .clk(clk), .we(i_rd == 3'b001 & i_rd_we == 1), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r2(.in(i_wdata), .out(r2v), .clk(clk), .we(i_rd == 3'b010 & i_rd_we == 1), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r3(.in(i_wdata), .out(r3v), .clk(clk), .we(i_rd == 3'b011 & i_rd_we == 1), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r4(.in(i_wdata), .out(r4v), .clk(clk), .we(i_rd == 3'b100 & i_rd_we == 1), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r5(.in(i_wdata), .out(r5v), .clk(clk), .we(i_rd == 3'b101 & i_rd_we == 1), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r6(.in(i_wdata), .out(r6v), .clk(clk), .we(i_rd == 3'b110 & i_rd_we == 1), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r7(.in(i_wdata), .out(r7v), .clk(clk), .we(i_rd == 3'b111 & i_rd_we == 1), .gwe(gwe), .rst(rst));

    // Nbit_reg #(n) r0(.in(i_rd == 3'b000 & i_rd_we == 1), .out(), .clk(clk), .we( i_rd_we), .gwe(gwe), .rst(rst));

    /*
    Nbit_reg #(n) r0(r0v, , clk, i_rd_we, gwe, rst);
    Nbit_reg #(n) r1(r1v, ... , clk, i_rd_we, gwe, rst);
    Nbit_reg #(n) r2(r2v, ... , clk, i_rd_we, gwe, rst);
    Nbit_reg #(n) r3(r3v, ... , clk, i_rd_we, gwe, rst);
    Nbit_reg #(n) r4(r4v, ... , clk, i_rd_we, gwe, rst);
    Nbit_reg #(n) r5(r5v, ... , clk, i_rd_we, gwe, rst);
    Nbit_reg #(n) r6(r6v, ... , clk, i_rd_we, gwe, rst);
    Nbit_reg #(n) r7(r7v, ... , clk, i_rd_we, gwe, rst);
    */

    assign o_rs_data = (i_rs == 3'b000) ? r0v : 
                       (i_rs == 3'b001) ? r1v : 
                       (i_rs == 3'b010) ? r2v : 
                       (i_rs == 3'b011) ? r3v : 
                       (i_rs == 3'b100) ? r4v : 
                       (i_rs == 3'b101) ? r5v : 
                       (i_rs == 3'b110) ? r6v : r7v;    

    assign o_rt_data = (i_rt == 3'b000) ? r0v : 
                       (i_rt == 3'b001) ? r1v : 
                       (i_rt == 3'b010) ? r2v : 
                       (i_rt == 3'b011) ? r3v : 
                       (i_rt == 3'b100) ? r4v : 
                       (i_rt == 3'b101) ? r5v : 
                       (i_rt == 3'b110) ? r6v : r7v; 


    // assign out based on condition 
    // ? : not mux

endmodule

/* Qiao Xu, Mili Aguayo 
   qiaoqiao, saguayo
*/

`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   input  wire [15:0] i_remainder,
                   input  wire [15:0] i_quotient,
                   output wire [15:0] o_dividend,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);

      wire[15:0] dividend [15:0];
      wire[15:0] remainder [15:0];
      wire[15:0] quotient [15:0];

      // Iteration for 16 times: Initial value for remainder and quotient: 16'b0. The first iteration
      lc4_divider_one_iter lc4d0(.i_dividend(i_dividend[15:0]),.i_divisor(i_divisor[15:0]),.i_remainder(16'b0),.i_quotient(16'b0),.o_dividend(dividend[0]),.o_remainder(remainder[0]),.o_quotient(quotient[0]));
      
      // Loop
      genvar i;
      for (i=0; i<=14; i=i+1) begin
          lc4_divider_one_iter lc4d(.i_dividend(dividend[i]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[i]),.i_quotient(quotient[i]),.o_dividend(dividend[i+1]),.o_remainder(remainder[i+1]),.o_quotient(quotient[i+1]));
      end
      
      assign o_remainder[15:0] = remainder[15];
      assign o_quotient[15:0] = quotient[15];
      assign o_dividend[15:0] = dividend[15];

      /*
      lc4_divider_one_iter lc4d1(.i_dividend(dividend[0]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[0]),.i_quotient(quotient[0]),.o_dividend(dividend[1]),.o_remainder(remainder[1]),.o_quotient(quotient[1]));
      lc4_divider_one_iter lc4d2(.i_dividend(dividend[1]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[1]),.i_quotient(quotient[1]),.o_dividend(dividend[2]),.o_remainder(remainder[2]),.o_quotient(quotient[2]));
      lc4_divider_one_iter lc4d3(.i_dividend(dividend[2]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[2]),.i_quotient(quotient[2]),.o_dividend(dividend[3]),.o_remainder(remainder[3]),.o_quotient(quotient[3]));
      lc4_divider_one_iter lc4d4(.i_dividend(dividend[3]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[3]),.i_quotient(quotient[3]),.o_dividend(dividend[4]),.o_remainder(remainder[4]),.o_quotient(quotient[4]));
      lc4_divider_one_iter lc4d5(.i_dividend(dividend[4]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[4]),.i_quotient(quotient[4]),.o_dividend(dividend[5]),.o_remainder(remainder[5]),.o_quotient(quotient[5]));
      lc4_divider_one_iter lc4d6(.i_dividend(dividend[5]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[5]),.i_quotient(quotient[5]),.o_dividend(dividend[6]),.o_remainder(remainder[6]),.o_quotient(quotient[6]));
      lc4_divider_one_iter lc4d7(.i_dividend(dividend[6]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[6]),.i_quotient(quotient[6]),.o_dividend(dividend[7]),.o_remainder(remainder[7]),.o_quotient(quotient[7]));
      lc4_divider_one_iter lc4d8(.i_dividend(dividend[7]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[7]),.i_quotient(quotient[7]),.o_dividend(dividend[8]),.o_remainder(remainder[8]),.o_quotient(quotient[8]));
      lc4_divider_one_iter lc4d9(.i_dividend(dividend[8]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[8]),.i_quotient(quotient[8]),.o_dividend(dividend[9]),.o_remainder(remainder[9]),.o_quotient(quotient[9]));
      lc4_divider_one_iter lc4d10(.i_dividend(dividend[9]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[9]),.i_quotient(quotient[9]),.o_dividend(dividend[10]),.o_remainder(remainder[10]),.o_quotient(quotient[10]));
      lc4_divider_one_iter lc4d11(.i_dividend(dividend[10]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[10]),.i_quotient(quotient[10]),.o_dividend(dividend[11]),.o_remainder(remainder[11]),.o_quotient(quotient[11]));
      lc4_divider_one_iter lc4d12(.i_dividend(dividend[11]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[11]),.i_quotient(quotient[11]),.o_dividend(dividend[12]),.o_remainder(remainder[12]),.o_quotient(quotient[12]));
      lc4_divider_one_iter lc4d13(.i_dividend(dividend[12]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[12]),.i_quotient(quotient[12]),.o_dividend(dividend[13]),.o_remainder(remainder[13]),.o_quotient(quotient[13]));
      lc4_divider_one_iter lc4d14(.i_dividend(dividend[13]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[13]),.i_quotient(quotient[13]),.o_dividend(dividend[14]),.o_remainder(remainder[14]),.o_quotient(quotient[14]));
      lc4_divider_one_iter lc4d15(.i_dividend(dividend[14]),.i_divisor(i_divisor[15:0]),.i_remainder(remainder[14]),.i_quotient(quotient[14]),.o_dividend(dividend[15]),.o_remainder(remainder[15]),.o_quotient(quotient[15]));       
      */

endmodule // lc4_divider

/* make check : <verilog syntax error free
make test : pass all the test cases
make synth : From verilog abstraction to Gate-level implementation
make impl: Wiring, placement and routing 
make zip: submission */

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);
      
      // New reminder
      wire[15:0] w=16'b0;
      wire[15:0] s_reminder = i_remainder << 1 | (i_dividend >> 15 & 16'd1);
      wire[15:0] p_reminder = s_reminder - i_divisor;

      // assign mux_bit = s_reminder > i_divisor ? 0 : 1;      

      // Out Remainder
      assign o_remainder = (i_divisor == 16'd0)? w : (s_reminder < i_divisor) ? s_reminder : p_reminder;


      // Out Dividend
      assign o_dividend = (i_divisor == 16'd0)? w : i_dividend << 1;

      // Quotient
      wire[15:0] s_quotient = i_quotient << 1;
      wire[15:0] p_quotient = s_quotient | 16'd1;

      // Out Quotient
      assign o_quotient = (i_divisor == 16'd0)? w : (s_reminder < i_divisor) ? s_quotient : p_quotient;

endmodule

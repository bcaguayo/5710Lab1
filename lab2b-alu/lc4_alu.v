/* INSERT NAME AND PENNKEY HERE */

`timescale 1ns / 1ps
`default_nettype none

// One CLA module
module clam(input wire [15:0] inA,
            input wire [15:0] inB,
            input wire ci_n,
            output wire [15:0] a_sum);
      
      cla16 c(.a(inA), .b(inB), .cin(ci_n), .sum(a_sum));
endmodule

module arith(input wire [15:0]  insn,
             input wire [15:0]  reg_1, reg_2,
             output wire [15:0] outR, out);
      
      // Sum
      wire c_in = (insn[5] == 1'b1) ? 0 :
                  (insn[4] == 1'b0) ? 0 : 1;
      wire imm = {{11{insn[4]}}, insn[4:0]};
      wire [15:0] in_B = (insn[5] == 1'b1) ? imm : reg_2;
      
      wire [15:0] s_sum;
      clam ca(.inA(reg_1), .inB(in_B), .ci_n(c_in), .a_sum(s_sum));

      // Division
      wire[15:0] dividend;
      wire[15:0] remainder;
      wire[15:0] quotient;
      lc4_divider divD(.i_dividend(reg_1), .i_divisor(reg_2), .i_remainder(16'b0), .i_quotient(16'b0),
                       .o_dividend(dividend), .o_remainder(remainder), .o_quotient(quotient));

      // put in s_sum when CLA is done
      assign out = (insn[3] == 1'b0) ? s_sum : (insn[4] == 1'b0) ? reg_1 * reg_2 : quotient;
      assign outR = remainder;
endmodule

module srlmod(input wire [15:0]  insn, reg_1,
              output wire [15:0] out);

      wire[15:0] shifter = {12'h000, insn[3:0]};
      wire [15:0] s_shift = $signed(reg_1) >>> shifter;

      // SIGN EXT: {{12{imm4[3]}}, imm4}
      // ZERO EXT: {12’b0, uimm4}
      
      assign out = (insn[5:4] == 2'b00) ? reg_1 << shifter  :        // SLL
                   (insn[5:4] == 2'b01) ? s_shift           :        // SRA
                   (insn[5:4] == 2'b10) ? reg_1 >> shifter  :        // SRL
                   16'h0000;
endmodule

module lc4_alu(input wire [15:0]  i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);

      // Instruction Type
      wire[3:0] ins15_12 = i_insn[15:12];
      wire [15:0] w_default = 16'h0000;

      // <boolean statement> ? case_1 : <bool statement 2> ?  Case 2 : Case 3

      // SECTION 0000
      wire [15:0] b_out;
      wire [15:0] s_ext = {{7{i_insn[8]}}, i_insn[8:0]};
      clam cb(.inA(i_pc), .inB(s_ext), .ci_n(16'd1), .a_sum(b_out));
      
      // SECTION 0001
      wire [15:0] a_out;
      wire [15:0] a_remainder;
      arith a(.insn(i_insn), .reg_1(i_r1data), .reg_2(i_r2data), .out(a_out), .outR(a_remainder));

      // SECTION 0010
      wire [15:0] sign_1 = ($signed(i_r1data) <  $signed(i_r2data)) ? 16'hFFFF : 
                           ($signed(i_r1data) == $signed(i_r2data)) ? 16'h0000 : 16'h0001;
      wire [15:0] sign_2 = (i_r1data < i_r2data) ? 16'hFFFF : (i_r1data == i_r2data) ? 16'h0000 : 16'h0001;

      wire [15:0] s_extn = {{9{i_insn[6]}}, i_insn[6:0]};
      wire [15:0] sign_3 = ($signed(i_r1data) <  $signed(s_extn)) ? 16'hFFFF : 
                           ($signed(i_r1data) == $signed(s_extn)) ? 16'h0000 : 16'h0001;

      wire [15:0] z_ext = {9'd0, i_insn[6:0]};
      wire [15:0] sign_4 = (i_r1data < z_ext) ? 16'hFFFF : (i_r1data == z_ext) ? 16'h0000 : 16'h0001;

      wire [15:0] cmp = (i_insn[8:7] == 2'b00) ? sign_1 : 
                        (i_insn[8:7] == 2'b01) ? sign_2 :
                        (i_insn[8:7] == 2'b10) ? sign_3 : sign_4;
      

      // SECTION 0100
      wire [15:0] jsr =  {i_pc[15], i_insn[10:0], 4'h0};
      wire [15:0] jsrr = (i_insn[11] == 1'b0) ? i_r1data : jsr;

      // SECTION 0101
      wire [15:0] o_anxo = (i_insn[4:3] == 2'b00) ? i_r1data & i_r2data :    // AND
                            (i_insn[4:3] == 2'b01) ? ~i_r1data :              // NOT
                            (i_insn[4:3] == 2'b10) ? i_r1data | i_r2data :   // OR
                            i_r1data ^ i_r2data;                              // XOR
      wire [15:0] s_extl  = {{11{i_insn[4]}}, i_insn[4:0]};
      wire [15:0] o_logic = (i_insn[5] == 1'b1) ? (i_r1data & s_extl) : o_anxo;

      // SECTION 0110 LDR && SECTION 0111 STR
      wire [15:0] s_exdr = {{10{i_insn[5]}}, i_insn[5:0]};
      wire [15:0] ldstr;
      clam cs(.inA(i_r1data), .inB(s_exdr), .ci_n(16'd0), .a_sum(ldstr));

      // SECTION 1000 RTI 
      wire [15:0] rti = i_r1data;

      // SECTION 1001
      wire [15:0] constt = {{7{i_insn[8]}}, i_insn[8:0]};

      // SECTION 1010
      wire [15:0] s_out;
      srlmod srm(.insn(i_insn), .reg_1(i_r1data), .out(s_out));
      wire [15:0] s_lrm = (i_insn[5:4] == 2'b11) ? a_remainder : s_out;

      // SECTION 1100
      wire [15:0] im11b =  {{5{i_insn[10]}}, i_insn[10:0]};
      wire [15:0] jmp;
      clam cj(.inA(i_pc), .inB(im11b), .ci_n(16'd1), .a_sum(jmp));
      wire [15:0] jmpr =   (i_insn[11] == 1'b0) ? i_r1data : jmp;

      // SECTION 1101
      wire [15:0] hconst = {i_insn[7:0], i_r1data[7:0]};

      // SECTION 1111 TRAP
      wire [15:0] trap = {8'h80, i_insn[7:0]};      

      // Result
      assign o_result = (ins15_12 == 4'h0) ? b_out : 
                        (ins15_12 == 4'h1) ? a_out : 
                        (ins15_12 == 4'h2) ? cmp : 
                        (ins15_12 == 4'h4) ? jsrr : 
                        (ins15_12 == 4'h5) ? o_logic : 
                        (ins15_12 == 4'h6) ? ldstr : 
                        (ins15_12 == 4'h7) ? ldstr : 
                        (ins15_12 == 4'h8) ? rti :           // RTI 
                        (ins15_12 == 4'h9) ? constt : 
                        (ins15_12 == 4'hA) ? s_lrm :
                        (ins15_12 == 4'hC) ? jmpr :
                        (ins15_12 == 4'hD) ? hconst :
                        (ins15_12 == 4'hF) ? trap : w_default;

endmodule

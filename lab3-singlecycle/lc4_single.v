/* TODO: name and PennKeys of all group members here
 *
 * lc4_single.v
 * Implements a single-cycle data path
 *
 */

/*
TODO: 
Write NZP
Some PC Logic
Add data into the register
*/

/*
to make zip
touch zip file list
*/

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // Main clock
    input  wire        rst,                // Global reset
    input  wire        gwe,                // Global we for single-step clock
    output wire [15:0] o_cur_pc,           // Address to read from instruction memory
    input  wire [15:0] i_cur_insn,         // Output of instruction memory
    output wire [15:0] o_dmem_addr,        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
    input  wire [15:0] i_cur_dmem_data,    // Output of data memory
    output wire        o_dmem_we,          // Data memory write enable
    output wire [15:0] o_dmem_towrite,     // Value to write to data memory

    // Testbench signals are used by the testbench to verify the correctness of your datapath.
    // Many of these signals simply export internal processor state for verification (such as the PC).
    // Some signals are duplicate output signals for clarity of purpose.
    //
    // Don't forget to include these in your schematic!

    output wire [1:0]  test_stall,         // Testbench: is this a stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc,        // Testbench: program counter
    output wire [15:0] test_cur_insn,      // Testbench: instruction bits
    output wire        test_regfile_we,    // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel,  // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data,  // Testbench: value to write into the register file
    output wire        test_nzp_we,        // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits,  // Testbench: value to write to NZP bits
    output wire        test_dmem_we,       // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr,     // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data,     // Testbench: value read/writen from/to memory
   
    input  wire [7:0]  switch_data,        // Current settings of the Zedboard switches
    output wire [7:0]  led_data            // Which Zedboard LEDs should be turned on?
    );

   // By default, assign LEDs to display switch inputs to avoid warnings about
   // disconnected ports. Feel free to use this for debugging input/output if
   // you desire.
   assign led_data = switch_data;

   
   /* DO NOT MODIFY THIS CODE */
   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   assign test_stall = 2'b0; 

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc) 

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   /* END DO NOT MODIFY THIS CODE */


   /*******************************
    * TODO: INSERT YOUR CODE HERE *
    *******************************/

   // Decoder
   wire [2:0] r1sel, r2sel, wsel;
   wire r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;
   lc4_decoder decoder(.insn(i_cur_insn), .r1sel(r1sel), .r1re(r1re), .r2sel(r2sel), .r2re(r2re), .wsel(wsel), .regfile_we(regfile_we),.nzp_we(nzp_we), .select_pc_plus_one(select_pc_plus_one), .is_load(is_load), .is_store(is_store), .is_branch(is_branch), .is_control_insn(is_control_insn));

   // Fetch: PC+1
   // cla16 cla_pc(.a(pc),.b(16'd0),.cin(1'b1),.sum(next_pc));
   assign o_cur_pc = pc;

   // Data Decode
   wire [15:0] o_Rsdata, o_Rtdata, i_wdata;

   // Ctrl_Insn: JSR, JSRR, TRAP

   // R7 = PC + 1: i_rd_we enable(1), i_rd/wsel = 111, i_wdata pc+1
   wire irdwe = (i_cur_insn[15:12] == 4'h4 | i_cur_insn[15:12] == 4'hF) ? 1'b1 : regfile_we;
   wire [2:0] ird = (i_cur_insn[15:12] == 4'h4 | i_cur_insn[15:12] == 4'hF) ? 3'b111 : wsel;
   wire [15:0] iwdata = (i_cur_insn[15:12] == 4'h4 | i_cur_insn[15:12] == 4'hF) ? pc_plus_one : i_wdata;

   // Ctrl_Insn: RTI | PC = R7
   wire [2:0] r1select = (i_cur_insn[15:12] == 4'b1000) ? 3'b111 : r1sel;

   // wsel, regfile_we, i_wdata
   lc4_regfile #(.n(16)) register(.clk(clk),.rst(rst),.gwe(gwe),.i_rs(r1select),.o_rs_data(o_Rsdata),.i_rt(r2sel),.o_rt_data(o_Rtdata),.i_rd(ird),.i_wdata(iwdata),.i_rd_we(irdwe));

   // ALU
   wire[15:0] o_ALU;
   lc4_alu alu (.i_insn(i_cur_insn), .i_pc(pc), .i_r1data(o_Rsdata), .i_r2data(o_Rtdata), .o_result(o_ALU));

   // Memory
   assign o_dmem_we = is_store;
   assign o_dmem_towrite = (is_load  == 1'b1) ? i_cur_dmem_data :
                           (is_store == 1'b1) ? o_Rtdata : 16'd0; // DMwe=is_sw on lecture
   assign o_dmem_addr = (is_load | is_store) ? o_ALU : 16'd0;

   // if load,  i_cur_dmem_data 
   // if str, put o_Rt_Data into memory
   // Writeback
   wire [15:0] regInputMux;
   wire [15:0] selected_from_DM = (is_load == 1'b1) ? i_cur_dmem_data : o_ALU;
   assign regInputMux = (select_pc_plus_one == 16'd1) ? next_pc : selected_from_DM;
   assign i_wdata = regInputMux;

   // NZP Register, starts at 0000h at bootup
   wire [2:0] nzp;
   /*
   wire [2:0] next_nzp = (i_wdata[15] == 1'b1) ? 3'b100 :
                         ($signed(i_wdata) == 16'h0000) ? 3'b010 : 3'b001;
   */
   wire [2:0] next_nzp = ($signed(i_wdata) == 16'd0) ? 3'b010 :
                         (i_wdata[15] ==  1'b1) ? 3'b100 : 3'b001;

   // If CMP, CMPU, CMPI, CMPIU get ALU result
   // wire [2:0] nzp_mux = (i_cur_insn[15:12] == 4'b0010) ? alu_nzp : next_nzp;
   
   // put in nzp
   Nbit_reg #(3, 3'b000) nzp_reg (.in(next_nzp), .out(nzp), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));

   // Branch Unit   
   // Test cases: test_alu, test_br, test_ld_br, test_mem, test_all

   // Branch ------------------------------------------------------------------
   // HOW DO I ACCESS R7
   wire [15:0] pcInputMux;
   wire [15:0] pc_plus_one;
   wire [15:0] pc_ctrl_insn;

   // Compute PC Plus One
   wire [15:0] s_ext_br = {{7{i_cur_insn[8]}}, i_cur_insn[8:0]};

   // Branch is taken check NZP vs insn[11:9]
   wire take_br = (nzp[2] & (i_cur_insn[11] == 1'b1)) ? 1'b1 :
                  (nzp[1] & (i_cur_insn[10] == 1'b1)) ? 1'b1 :
                  (nzp[0] & (i_cur_insn[9] == 1'b1)) ? 1'b1 : 1'b0;

   // If Branch that isn't NOP, add IMM9
   wire [15:0] b_in = (is_branch & take_br)? s_ext_br : 16'd0;
   cla16 cla_branch(.a(pc),.b(b_in),.cin(1'b1),.sum(pc_plus_one));   
   
   // JSR & JSRR  -------------------------------------------------------------
   wire [15:0] s_ext_jsr = {i_cur_insn[10], i_cur_insn[10:0], 4'b0}; // JSR Sign Ext
   wire [15:0] pc_jsr = (pc & 16'h8000) | s_ext_jsr;   // JSR PC
   wire [15:0] pc_jsrr = (i_cur_insn[11] == 1'b1) ? pc_jsr : o_Rsdata;   // JSR or JSRR

   // JMP & JMPR  -------------------------------------------------------------
   wire [15:0] pc_jmp;
   wire [15:0] s_ext_jmp = {{5{i_cur_insn[10]}}, i_cur_insn[10:0]};     // JMP Sign Ext
   cla16 cla_jmp(.a(pc),.b(s_ext_jmp),.cin(1'b1),.sum(pc_jmp));       // JMP
   wire [15:0] pc_jmpr = (i_cur_insn[11] == 1'b1) ? pc_jmp : o_Rsdata;     // JMP or JMPR

   // TRAP  -------------------------------------------------------------------
   wire[15:0] pc_trap = {8'h80, i_cur_insn[7:0]};

   // RTI  --------------------------------------------------------------------
   wire[15:0] pc_rti = o_Rsdata; // Selected to be Rs above

   assign pc_ctrl_insn = (i_cur_insn[15:12] == 4'h4) ? pc_jsrr :
                         (i_cur_insn[15:12] == 4'hC) ? pc_jmpr :
                         (i_cur_insn[15:12] == 4'hF) ? pc_trap : pc_rti;

   assign next_pc = is_control_insn? pc_ctrl_insn : pc_plus_one;
   /*
   Questions I still have:
   Do I need CMP? YES
   How to access R7?
   How to access the Privilege Bit and assign it. Does it go on its separate register NO
   Do I need to do anything as signed???
   */

   // Testbench signals
   assign test_stall          = 2'b00;          // Testbench: is this a stall cycle? (don't compare the test values)
   assign test_cur_pc         = pc;             // Testbench: program counter
   assign test_cur_insn       = i_cur_insn;     // Testbench: instruction bits
   assign test_regfile_we     = regfile_we;     // Testbench: register file write enable
   assign test_regfile_wsel   = wsel;           // Testbench: which register to write in the register file 
   assign test_regfile_data   = iwdata;        // Testbench: value to write into the register file
   assign test_nzp_we         = nzp_we;         // Testbench: NZP condition codes write enable
   assign test_nzp_new_bits   = next_nzp;            // Testbench: value to write to NZP bits
   assign test_dmem_we        = o_dmem_we;      // Testbench: data memory write enable
   assign test_dmem_addr      = o_dmem_addr;    // Testbench: address to read/write memory
   assign test_dmem_data      = o_dmem_towrite; // Testbench: value read/writen from/to memory


   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    * 
    * To disable the entire block add the statement
    * `define NDEBUG
    * to the top of your file.  We also define this symbol
    * when we run the grading scripts.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
   //$display(...);
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecial.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      // $display(...);
   end
`endif
endmodule

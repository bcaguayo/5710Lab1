/* TODO: name and PennKeys of all group members here */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this is stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter
    output wire [15:0] test_cur_insn, // Testbench: instruction bits
    output wire        test_regfile_we, // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );

   // By default, assign LEDs to display switch inputs to avoid warnings about disconnected ports.
   assign led_data = switch_data;

   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   /*
   + 0: no stall
   + 1: reserved for the superscalar design; for this lab, never set test_stall to 1
   + 2: flushed due to misprediction or because the first real instruction hasn't made it through to the writeback stage yet
   + 3: stalled due to load-to-use penalty
   */
   
   wire [1:0] in_stall = 2'b00;    
   wire [15:0] nop_insn = 16'h0000;

   //____________________________________FETCH___________________________________________

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc) 

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // propagate next_pc
   assign next_pc = (ld_to_use_stall) ? pc : pc + 1;

    // Fetch: PC+1
   assign o_cur_pc = pc;

   wire we_decode = (ld_to_use_stall) ? 1'b0 : 1'b1;

   //______________________________D Pipeline Register___________________________________

   /// Register Values: PC
   wire [15:0] pc_D, next_pc_D, insn_D;
   wire [1:0]  stall_D; 
   Nbit_reg #( 2, 2'd2)     D_stall_reg   (.in(in_stall),   .out(stall_D),  .clk(clk), .we(we_decode), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h8200) D_pc_reg      (.in(o_cur_pc),   .out(pc_D),     .clk(clk), .we(we_decode), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) D_next_pc_reg (.in(next_pc),    .out(next_pc_D),.clk(clk), .we(we_decode), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) D_insn_reg    (.in(i_cur_insn), .out(insn_D),   .clk(clk), .we(we_decode), .gwe(gwe), .rst(rst));   
   
   //___________________________________DECODE___________________________________________

   wire [2:0] r1sel, r2sel, wsel;
   wire r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;
   lc4_decoder decoder(.insn(insn_D), .r1sel(r1sel), .r1re(r1re), .r2sel(r2sel), .r2re(r2re), .wsel(wsel), 
                       .regfile_we(regfile_we), .nzp_we(nzp_we), .select_pc_plus_one(select_pc_plus_one), .is_load(is_load), 
                       .is_store(is_store), .is_branch(is_branch), .is_control_insn(is_control_insn));

   // Data Decode
   wire [15:0] o_Rsdata, o_Rtdata, i_wdata;

   // Load-To-Use Stall: If Execute is Load, and Decode uses that register, stall
   wire is_load_X = ctrl_sign_X[3];
   wire [2:0] wsel_X = regfile_data_X[3:1];
   wire target_match = (wsel_X == r1sel) || ((wsel_X == r2sel) && !is_load);
   wire ld_to_use_stall = (insn_X[15:9] == 7'd0) ? 1'b0 :
                          (is_load_X && !is_store && target_match) ? 1'b1 : 1'b0;
   wire [1:0] stall_D_S = (ld_to_use_stall) ? 2'b11 : stall_D;

   // WIP
   /*
   wire irdwe;
   wire [2:0]  ird, r1select;
   wire [15:0] iwdata;   
   
   assign irdwe   = regfile_we;
   assign ird     = wsel;
   assign iwdata  = i_wdata; 
   assign r1select = r1sel;
   */
   // dmem_we_W, dmem_towrite_W, dmem_addr_W
   /*
   assign irdwe  = (insn_W[15:12] == 4'h4 | insn_W[15:12] == 4'hF) ? 1'b1 : rgfile_we_W;
   assign ird    = (insn_W[15:12] == 4'h4 | insn_W[15:12] == 4'hF) ? 3'd7 : wselect_W;
   assign iwdata = (insn_W[15:12] == 4'h4 | insn_W[15:12] == 4'hF) ? pc_plus_one : i_wdata;
   */
   
   // Load: if is load W, set wsel = wSelW and i wdata to i curr, irdwe to 1
   assign i_wdata = (is_ld_W == 1'b1) ? regInputMux : alu_W;
   wire irdwe = (ld_to_use_stall) ? 1'b0 : 
                (is_ld_W == 1'b1) ? 1'b1 : regfile_data_W[0];

   // ********************** REGFILE
   lc4_regfile #(.n(16)) register(.clk(clk), .rst(rst), .gwe(gwe),  .i_rs(r1sel),  .o_rs_data(o_Rsdata), .i_rt(r2sel),
                                  .o_rt_data(o_Rtdata), .i_rd(regfile_data_W[3:1]), .i_wdata(i_wdata), .i_rd_we(irdwe));
   
   /* r1re_D && regfile_we_W && (r1sel_D == wsel_W)   ->    pass regInputMux into o_Rsdata
      r2re_D && regfile_we_W && (r2sel_D == wsel_W)   ->    pass regInputMux into o_Rtdata
   */
   // WD Bypass   
   wire regfile_we_W_D = regfile_data_W[0];
   wire [2:0] wsel_W_D = regfile_data_W[3:1];
   wire [15:0] rsdata_D = (r1re && regfile_we_W_D && (r1sel == wsel_W_D)) ? regInputMux : o_Rsdata;
   wire [15:0] rtdata_D = (r2re && regfile_we_W_D && (r2sel == wsel_W_D)) ? regInputMux : o_Rtdata;

   // Load-To-Use Assigning
   wire [15:0] insn_D_S = (ld_to_use_stall) ? nop_insn  : insn_D;
   // wire [11:0] regfile_data_in_S = (ld_to_use_stall) ? 12'h000   : regfile_data_in;
   // wire  [5:0] ctrl_sign_in_S =    (ld_to_use_stall) ? 6'b010010 : ctrl_sign_in;

   //______________________________X Pipeline Register___________________________________

   // Register Values: pc_D, i_cur_insn, o_Rsdata, o_Rtdata, i_wdata
   // r1sel, r1re, r2sel, r2re, wsel, regfile_we
   // nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn

   wire [1:0]  stall_X; 
   Nbit_reg #( 2, 2'd2)     X_stall_reg (.in(stall_D_S),  .out(stall_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire [15:0] pc_X, next_pc_X, insn_X, rsdata_X, rtdata_X, wdata_X;

   Nbit_reg #(16, 16'h8200) X_pc_reg      (.in(pc_D),     .out(pc_X),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) X_next_pc_reg (.in(next_pc_D),.out(next_pc_X),.clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) X_insn_reg    (.in(insn_D_S), .out(insn_X),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) X_rs_reg      (.in(rsdata_D), .out(rsdata_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) X_rt_reg      (.in(rtdata_D), .out(rtdata_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) X_wdata_reg   (.in(i_wdata),  .out(wdata_X),  .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // r1sel[3], r1re[1], r2sel[3], r2re[1], wsel[3], regfile_we[1]
   // [11:9]    [8]      [7:5]     [4]      [3:1]    [0]
   wire [11:0] regfile_data_in = {r1sel,   r1re,   r2sel,   r2re,   wsel,   regfile_we};
   wire [11:0] regfile_data_X;
   Nbit_reg #(12, 12'd0) X_regfile_data_reg (.in(regfile_data_in), .out(regfile_data_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // wire nzp_we_X, select_pc_plus_one_X, is_load_X, is_store_X, is_branch_X, is_control_insn_X;
   wire [5:0] ctrl_sign_in = {nzp_we,   select_pc_plus_one,   is_load,   is_store,   is_branch,   is_control_insn};
   wire [5:0] ctrl_sign_X;
   Nbit_reg #(6, 6'd0) X_ctrl_sign_reg (.in(ctrl_sign_in), .out(ctrl_sign_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   //___________________________________EXECUTE__________________________________________

   // Bypass
   /* r1re_X && regfile_we_M && (r1sel_X == wsel_M)   ->    pass o_ALU into o_Rsdata
      r2re_X && regfile_we_M && (r2sel_X == wsel_M)   ->    pass o_ALU into o_Rtdata
      r1re_X && regfile_we_W && (r1sel_X == wsel_W)   ->    pass regInputMux into o_Rsdata
      r2re_X && regfile_we_W && (r2sel_X == wsel_W)   ->    pass regInputMux into o_Rtdata
   */

   wire r1re_B = regfile_data_X[8];
   wire r2re_B = regfile_data_X[4];
   wire [2:0] r1sel_B = regfile_data_X[11:9];
   wire [2:0] r2sel_B = regfile_data_X[7:5];

   wire [2:0] wsel_M_B = regfile_data_M[3:1];
   wire [2:0] r2sel_M_B = regfile_data_M[7:5];
   wire [2:0] wsel_W_B = regfile_data_W[3:1];

   wire regfile_we_M_B = regfile_data_M[0];
   wire regfile_we_W_B = regfile_data_W[0];

   // MX WX Bypass
   wire [15:0] rsdata = (r1re_B && regfile_we_M_B && (r1sel_B == wsel_M_B)) ? alu_M : 
                      //(r1re_B && regfile_we_M_B && (r1sel_B == r2sel_M_B)) ? i_cur_dmem_data : 
                        (r1re_B && regfile_we_W_B && (r1sel_B == wsel_W_B)) ? regInputMux : rsdata_X;

   wire [15:0] rtdata = (r2re_B && regfile_we_M_B && (r2sel_B == wsel_M_B)) ? alu_M : 
                      //(r2re_B && regfile_we_M_B && (r2sel_B == r2sel_M_B)) ? i_cur_dmem_data : 
                        (r2re_B && regfile_we_W_B && (r2sel_B == wsel_W_B)) ? regInputMux : rtdata_X;

   wire[15:0] o_ALU;
   lc4_alu alu (.i_insn(insn_X), .i_pc(pc_X), .i_r1data(rsdata), .i_r2data(rtdata), .o_result(o_ALU));

   //______________________________M Pipeline Register___________________________________

   // Register Values: pc_D, i_cur_insn, o_Rsdata, o_Rtdata, i_wdata
   // r1sel, r1re, r2sel, r2re, wsel, regfile_we
   // nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn
   // o_ALU

   wire [1:0]  stall_M; 
   Nbit_reg #( 2, 2'd2)     M_stall_reg (.in(stall_X),  .out(stall_M),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire [15:0] pc_M, next_pc_M, insn_M, rsdata_M, rtdata_M, wdata_M;

   Nbit_reg #(16, 16'h8200) M_pc_reg      (.in(pc_X),     .out(pc_M),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) M_next_pc_reg (.in(next_pc_X),.out(next_pc_M),  .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) M_insn_reg    (.in(insn_X),   .out(insn_M),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) M_rs_reg      (.in(rsdata_X), .out(rsdata_M),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) M_rt_reg      (.in(rtdata_X), .out(rtdata_M),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) M_wdata_reg   (.in(wdata_X),  .out(wdata_M),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire [11:0] regfile_data_M;
   Nbit_reg #(12, 12'd0) M_regfile_data_reg (.in(regfile_data_X), .out(regfile_data_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire [5:0] ctrl_sign_M;
   Nbit_reg #(6, 6'd0) M_ctrl_sign_reg (.in(ctrl_sign_X), .out(ctrl_sign_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // New ALU
   wire [15:0] alu_M;
   Nbit_reg #(16, 16'h0000) M_alu_reg (.in(o_ALU), .out(alu_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   //____________________________________MEMORY__________________________________________

   wire is_str_M = ctrl_sign_M[2];
   wire is_ld_M  = ctrl_sign_M[3];

   wire is_str_W_B = ctrl_sign_W[2];

   assign o_dmem_we = is_str_M;
   // WM Bypass = Rd Load & Rt Store
   assign o_dmem_towrite = (is_str_W_B && is_ld_M && 
                           (regfile_data_M[3:1] == regfile_data_W[7:5])) ? dmem_towrite_W :
                           (is_ld_M  == 1'b1) ? i_cur_dmem_data :
                           (is_str_M == 1'b1) ? rtdata_M : 16'd0; // DMwe=is_sw on lecture
   assign o_dmem_addr =    (is_ld_M | is_str_M) ? alu_M : 16'd0;

   wire [1:0] stall_M_S = (stall_M == 2'b11) ? 2'b00 : stall_M; 

   //______________________________W Pipeline Register___________________________________

   // Register Values: pc_D, i_cur_insn, o_Rsdata, o_Rtdata, i_wdata
   // r1sel, r1re, r2sel, r2re, wsel, regfile_we
   // nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn
   // o_ALU
   // i_cur_dmem_data

   wire [1:0]  stall_W; 
   Nbit_reg #( 2, 2'd2)     W_stall_reg (.in(stall_M),  .out(stall_W),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire [15:0] pc_W, next_pc_W, insn_W, rsdata_W, rtdata_W, wdata_W;

   Nbit_reg #(16, 16'h8200) W_pc_reg      (.in(pc_M),     .out(pc_W),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) W_next_pc_reg (.in(next_pc_M),.out(next_pc_W),  .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) W_insn_reg    (.in(insn_M),   .out(insn_W),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) W_rs_reg      (.in(rsdata_M), .out(rsdata_W),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) W_rt_reg      (.in(rtdata_M), .out(rtdata_W),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) W_wdata_reg   (.in(wdata_M),  .out(wdata_W),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire [11:0] regfile_data_W;
   Nbit_reg #(12, 12'd0) W_regfile_data_reg (.in(regfile_data_M),  .out(regfile_data_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire [5:0] ctrl_sign_W;
   Nbit_reg #(6, 6'd0) W_ctrl_sign_reg (.in(ctrl_sign_M), .out(ctrl_sign_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   wire [15:0] alu_W;
   Nbit_reg #(16, 16'd0) W_alu_reg (.in(alu_M), .out(alu_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   // new curr Memory
   wire dmem_we_W;
   wire [15:0] dmem_towrite_W, dmem_addr_W;
   Nbit_reg #(1, 1'd0)   W_dmem_we_reg   (.in(o_dmem_we),      .out(dmem_we_W),      .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'd0) W_dmem_towr_reg (.in(o_dmem_towrite), .out(dmem_towrite_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'd0) W_dmem_addr_reg (.in(o_dmem_addr),    .out(dmem_addr_W),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   //__________________________________WRITEBACK_________________________________________

   // Next PC 
   wire is_ctrl_insn_W = ctrl_sign_W[0];
   wire is_br_W  = ctrl_sign_W[1];
   wire is_str_W = ctrl_sign_W[2];
   wire is_ld_W  = ctrl_sign_W[3];
   wire sel_pc_plus_one = ctrl_sign_W[4];

   // Reg Input MUX
   // if load,  o_dmem_towrite 
   // if str, put o_Rt_Data into memory
   wire [15:0] selected_from_DM = (is_ld_W == 1'b1) ? dmem_towrite_W : alu_W;
   wire [15:0] regInputMux = (sel_pc_plus_one == 1'd1) ? next_pc_W : selected_from_DM;
   
   // NZP Register
   wire [2:0] nzp;
   /*
   wire [2:0] next_nzp = (i_wdata[15] == 1'b1) ? 3'b100 :
                         ($signed(i_wdata) == 16'h0000) ? 3'b010 : 3'b001;
   */
   wire [2:0] next_nzp = ($signed(regInputMux) == 16'd0) ? 3'b010 :
                         (regInputMux[15] ==  1'b1)      ? 3'b100 : 3'b001;

   // If CMP, CMPU, CMPI, CMPIU get ALU result
   // wire [2:0] nzp_mux = (i_cur_insn[15:12] == 4'b0010) ? alu_nzp : next_nzp;
   
   // put in nzp, starts at 000 at bootup
   Nbit_reg #(3, 3'b000) nzp_reg (.in(next_nzp), .out(nzp), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));

   // Branch Unit      

   // Branch ------------------------------------------------------------------
   wire [15:0] pcInputMux;
   wire [15:0] pc_plus_one;
   wire [15:0] pc_ctrl_insn;

   // Compute PC Plus One
   wire [15:0] s_ext_br = {{7{insn_W[8]}}, insn_W[8:0]};

   // Branch is taken check NZP vs insn[11:9]
   wire take_br = (nzp[2] & (insn_W[11] == 1'b1)) ? 1'b1 :
                  (nzp[1] & (insn_W[10] == 1'b1)) ? 1'b1 :
                  (nzp[0] & (insn_W[9]  == 1'b1)) ? 1'b1 : 1'b0;

   // If Branch that isn't NOP, add IMM9
   wire [15:0] b_in = (is_br_W & take_br)? s_ext_br : 16'd0;
   cla16 cla_branch(.a(pc_W),.b(b_in),.cin(1'b1),.sum(pc_plus_one));
   
   // JSR & JSRR  -------------------------------------------------------------
   wire [15:0] s_ext_jsr = {insn_W[10], insn_W[10:0], 4'b0}; // JSR Sign Ext
   wire [15:0] pc_jsr    = (pc_W & 16'h8000) | s_ext_jsr;   // JSR PC
   wire [15:0] pc_jsrr   = (insn_W[11] == 1'b1) ? pc_jsr : rsdata_W;   // JSR or JSRR

   // JMP & JMPR  -------------------------------------------------------------
   wire [15:0] pc_jmp;
   wire [15:0] s_ext_jmp = {{5{insn_W[10]}}, insn_W[10:0]};     // JMP Sign Ext
   cla16 cla_jmp(.a(pc_W),.b(s_ext_jmp),.cin(1'b1),.sum(pc_jmp));       // JMP
   wire [15:0] pc_jmpr = (insn_W[11] == 1'b1) ? pc_jmp : rsdata_W;     // JMP or JMPR

   // TRAP  -------------------------------------------------------------------
   wire[15:0] pc_trap = {8'h80, insn_W[7:0]};

   wire rgfile_we_W  = regfile_data_W[0];
   wire [2:0] wselect_W  = regfile_data_W[3:1];
   wire [2:0] r1select_W = regfile_data_W[11:9];

   // Ctrl_Insn: JSR, JSRR, TRAP
   // R7 = PC + 1: i_rd_we enable(1), i_rd/wsel = 111, i_wdata pc+1

   // RTI  --------------------------------------------------------------------
   wire[15:0] pc_rti = rsdata_W; // Selected to be Rs above

   // Ctrl_Insn: RTI | PC = R7
   // WIP
   // assign r1select = (insn_D[15:12] == 4'b1000) ? 3'b111 : r1select_W;   

   // Assign  -----------------------------------------------------------------
   assign pc_ctrl_insn = (insn_W[15:12] == 4'h4) ? pc_jsrr :
                         (insn_W[15:12] == 4'hC) ? pc_jmpr :
                         (insn_W[15:12] == 4'hF) ? pc_trap : pc_rti;

   //assign next_pc = is_ctrl_insn_W? pc_ctrl_insn : pc_plus_one;

   // Set Test Wires Here
   assign test_stall          = stall_W;           // Testbench: is this a stall cycle? (don't compare the test values)
   assign test_cur_pc         = pc_W;              // Testbench: program counter
   assign test_cur_insn       = insn_W;            // Testbench: instruction bits
   assign test_regfile_we     = regfile_data_W[0];        // Testbench: register file write enable
   assign test_regfile_wsel   = regfile_data_W[3:1];      // Testbench: which register to write in the register file 
   assign test_regfile_data   = regInputMux;           // Testbench: value to write into the register file
   assign test_nzp_we         = ctrl_sign_W[5];    // Testbench: NZP condition codes write enable
   assign test_nzp_new_bits   = next_nzp;          // Testbench: value to write to NZP bits
   assign test_dmem_we        = dmem_we_W;         // Testbench: data memory write enable
   assign test_dmem_addr      = dmem_addr_W;       // Testbench: address to read/write memory
   assign test_dmem_data      = dmem_towrite_W;    // Testbench: value read/writen from/to memory

   // Test cases: test_alu, test_br, test_ld_br, test_mem, test_all, wireframe

   /*
   Questions I still have:
   Where to set NZP? Memory? Writeback? Writeback
   Should WE in registers be 1?  Yes
   What should the default values be for data? Just 0
   Regs and MX & Wx Bypassing? DONE
   Tests should pass by not breaking code? i guess

   What do I put in test_stall ?

   TODO:
   Wire In Pipeline Registers In Stages
   Wire In Pipeline Registers To TestBench
   Implement Bypass (logic done)

   CHECK WHERE EVERY WIRE IS COMING FROM
   */

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    * 
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      // $display("Insn: %H", insn_W);
      /*
      if (ld_to_use_stall) begin
         $display("Load insn: %H, Use insn: %H", insn_X, insn_D);
         $display("Stall: %H, %H, %H", stall_M, stall_M_S, stall_W);
      end
      */
      // $display("stall: %H, ld: %H, strX: %H, match: %H. Load insn: %H", 
      // stall_D_2, is_load_X, is_store, target_match, insn_X);
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
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      // $display(); 
   end
`endif
endmodule

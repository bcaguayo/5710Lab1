`timescale 1ns / 1ps
// Prevent implicit wire declaration
`default_nettype none
module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock
                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)
                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set
                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)
                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,
                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );
    assign led_data = switch_data;
    /***  YOUR CODE HERE ***/
    assign o_cur_pc = pc_F_A;

    wire [15:0] Insn_A, Insn_B;

    lc4_decoder Pipe_A(.insn(Insn_A),
        .r1sel(X_div_A[33:31]), 
        .r2sel(X_div_A[30:28]),
        .wsel(X_div_A[27:25]),
        .r1re(X_div_A[24]),
        .r2re(X_div_A[23]),
        .regfile_we(X_div_A[22]),
        .nzp_we(X_div_A[21]), 
        .select_pc_plus_one(X_div_A[20]),
        .is_load(X_div_A[19]), 
        .is_store(X_div_A[18]),
        .is_branch(X_div_A[17]), 
        .is_control_insn(X_div_A[16]));
    
    lc4_decoder Pipe_B(.insn(Insn_B),
        .r1sel(X_div_B[33:31]), 
        .r2sel(X_div_B[30:28]),
        .wsel(X_div_B[27:25]),
        .r1re(X_div_B[24]),
        .r2re(X_div_B[23]),
        .regfile_we(X_div_B[22]),
        .nzp_we(X_div_B[21]), 
        .select_pc_plus_one(X_div_B[20]),
        .is_load(X_div_B[19]), 
        .is_store(X_div_B[18]),
        .is_branch(X_div_B[17]), 
        .is_control_insn(X_div_B[16]));
    
    wire [15:0] o_rsdata_A, o_rsdata_B, o_rtdata_A, o_rtdata_B;            
    wire [15:0] o_ALU_A, o_ALU_B;   

    lc4_alu ALU_Pipe_A( 
        .i_insn(XM_A[15:0]),
        .i_pc(PC_X_A),
        .i_r1data(rs_bypass_A),
        .i_r2data(rt_bypass_A),
        .o_result(o_ALU_A));
    
    lc4_alu ALU_Pipe_B( 
        .i_insn(XM_B[15:0]),
        .i_pc(PC_X_B),
        .i_r1data(rs_bypass_B),
        .i_r2data(rt_bypass_B),
        .o_result(o_ALU_B));


    wire [15:0] rs_bypass_A, rs_bypass_B, 
                rt_bypass_A, rt_bypass_B,
                WM_A, WM_MM_B;   


//load_to_use
    wire load_to_use_A, load_to_use_B, load_to_use_within_A, load_to_use_within_B, XA_load_to_use_DB, XB_load_to_use_DA, DA_load_to_use_DB;
    wire load_to_use_A_tmp1;
    wire mem_hazard, A_to_B;
    
    assign mem_hazard = (X_div_A[19] || X_div_A[18]) && (X_div_B[19] || X_div_B[18]); 
    assign XB_load_to_use_DA = (XM_B[19]) && 
                               (((X_div_A[24]) && (X_div_A[33:31] == XM_B[27:25])) || 
                               ((X_div_A[23]) && (X_div_A[30:28] == XM_B[27:25]) && (!X_div_A[18])));
    assign load_to_use_A_tmp1 = (XM_B[22]) && ((X_div_A[24] && (X_div_A[33:31] == XM_B[27:25])) || 
                                (X_div_A[23] && (X_div_A[30:28] == XM_B[27:25]))) && (XM_A[27:25] == XM_B[27:25]);
    assign load_to_use_within_A = ((XM_A[19]) && (((X_div_A[24]) && (X_div_A[33:31] == XM_A[27:25])) || 
                          ((X_div_A[23]) && (X_div_A[30:28] == XM_A[27:25]) && (!X_div_A[18]))) && (~load_to_use_A_tmp1));
    assign load_to_use_A = load_to_use_within_A | XB_load_to_use_DA;

    assign load_to_use_B = ( 
    (XM_B[19] & (((X_div_B[33:31] == XM_B[27:25]) & X_div_B[24]) | ((X_div_B[30:28] == XM_B[27:25]) & !X_div_B[18] &X_div_B[23])) )
    & ~((((X_div_A[27:25] == X_div_B[33:31]) & X_div_B[24]) | ((X_div_A[27:25] == X_div_B[30:28]) & X_div_B[23])) & X_div_A[22] & (X_div_A[27:25] == XM_B[27:25])))   
    | ((XM_A[19] & (((X_div_B[33:31] == XM_A[27:25]) & X_div_B[24]) | ((X_div_B[30:28] == XM_A[27:25]) & !X_div_B[18] &X_div_B[23])) ) 
    & ~((((X_div_A[27:25] == X_div_B[33:31]) & X_div_B[24] )| ((X_div_A[27:25] == X_div_B[30:28]) & X_div_B[23])) & X_div_A[22] & (X_div_A[27:25] == XM_A[27:25]))
    & ~(( ((XM_B[27:25] == X_div_B[33:31]) & X_div_B[24] )| ((XM_B[27:25] == X_div_B[30:28]) & X_div_B[23])) & XM_B[22] & (XM_B[27:25] == XM_A[27:25])));   

    assign A_to_B =   ((X_div_A[27:25] == X_div_B[33:31]) && X_div_B[24] && X_div_A[22]) || 
                        ((X_div_A[27:25] == X_div_B[30:28]) && X_div_B[23] && ~X_div_B[18] && X_div_A[22]) || 
                        (X_div_B[17] && X_div_A[21]);                       
          

    Nbit_reg #(16, 16'b0) d_insn_reg_A (.in(input_D_A), .out(Insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_D_A));
    Nbit_reg #(34, 34'b0) x_insn_reg_A (.in(X_div_A), .out(XM_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_X_A));
    Nbit_reg #(34, 34'b0) m_insn_reg_A (.in(XM_A), .out(MW_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(1'b0));
    Nbit_reg #(34, 34'b0) w_insn_reg_A (.in(MW_A), .out(O_W_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(1'b0));

    Nbit_reg #(16, 16'b0) d_insn_reg_B (.in(input_D_B), .out(Insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_D_B));
    Nbit_reg #(34, 34'b0) x_insn_reg_B (.in(X_div_B), .out(XM_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_X_B));
    Nbit_reg #(34, 34'b0) m_insn_reg_B (.in(XM_B), .out(MW_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_M_B));
    Nbit_reg #(34, 34'b0) w_insn_reg_B (.in(MW_B), .out(O_W_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(1'b0));

    // Load to Branch
    wire load_branch_A, load_branch_B;
    assign load_branch_A = X_div_A[17] && ((XM_A[19] && ~XM_B[21]) | XM_B[19]);
    assign load_branch_B = X_div_B[17] && ((XM_A[19] && ~XM_B[21]) | XM_B[19]); 
      
//stall
    wire [1:0] input_stall_D_A, input_stall_D_B, input_stall_X_A, input_stall_X_B, input_stall_M_B;
    wire [1:0] o_stall_D_A, o_stall_D_B,  o_stall_X_A, o_stall_X_B, o_stall_M_A, o_stall_M_B;
    wire stall_A, stall_B;

    assign input_stall_D_A = (br_ctrl_X_A == 1 || br_ctrl_X_B == 1) ? 2'd2 :
                         (load_to_use_A || load_branch_A) ? 2'd3 :2'd0;
    assign input_stall_D_B = (br_ctrl_X_A == 1 || br_ctrl_X_B == 1) ? 2'd2 :
                         (load_to_use_A || load_branch_A || A_to_B || mem_hazard) ? 2'd1 :
                         (load_to_use_B || load_branch_B) ? 2'd3 :2'd0;
                   
    assign stall_A = (input_stall_D_A == 2'd3) ||( input_stall_D_A == 2'd1) || load_branch_A;
    assign stall_B = (input_stall_D_B == 2'd3) || (input_stall_D_B == 2'd1) || load_branch_A || load_branch_B;
    assign input_stall_X_A = ((Insn_A == 16'h0000) && (pc_X_A == 16'h0000)) ? 2'd2 : input_stall_D_A;
    assign input_stall_X_B = ((Insn_B == 16'h0000) && (d2x_pc_B == 16'h0000)) ? 2'd2 : input_stall_D_B;
    assign input_stall_M_B = (br_ctrl_X_A == 1) ? 2'd2 : o_stall_X_B;

    Nbit_reg #(2, 2'b10) d_stall_A (.in(input_stall_D_A), .out(o_stall_D_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | br_ctrl_X_A));
    Nbit_reg #(2, 2'b10) x_stall_A (.in(input_stall_X_A), .out(o_stall_X_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | br_ctrl_X_A));
    Nbit_reg #(2, 2'b10) m_stall_A (.in(o_stall_X_A), .out(o_stall_M_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) w_stall_A (.in(o_stall_M_A), .out(test_stall_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    Nbit_reg #(2, 2'b10) d_stall_B (.in(input_stall_D_B), .out(o_stall_D_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | br_ctrl_X_B));
    Nbit_reg #(2, 2'b10) x_stall_B (.in(input_stall_X_B), .out(o_stall_X_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | br_ctrl_X_B));
    Nbit_reg #(2, 2'b10) m_stall_B (.in(input_stall_M_B), .out(o_stall_M_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) w_stall_B (.in(o_stall_M_B), .out(test_stall_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


//flush
    wire flush_D_A, flush_D_B, flush_X_A, flush_X_B, flush_M_B;
    wire [15:0] input_D_A, input_D_B;
    wire [33:0] X_div_A,  XM_A, MW_A, O_W_A;
    wire [33:0] X_div_B, XM_B, MW_B, O_W_B;
    wire br_ctrl_X_A, branch_taken_A, br_ctrl_X_B, branch_taken_B; 
    wire pipe_switch;

    assign X_div_A[15:0] = Insn_A;
    assign X_div_B[15:0] = Insn_B;

    assign flush_D_A = br_ctrl_X_A | br_ctrl_X_B;
    assign flush_D_B = br_ctrl_X_B | br_ctrl_X_A;
    assign flush_X_A = stall_A | br_ctrl_X_A | br_ctrl_X_B;
    assign flush_X_B = stall_B | br_ctrl_X_B | pipe_switch | br_ctrl_X_A;
    assign flush_M_B = br_ctrl_X_A;

    assign pipe_switch = ~flush_X_A && ( (A_to_B || mem_hazard) || (load_to_use_B && ~A_to_B && ~mem_hazard) || load_branch_B);

    assign input_D_A = pipe_switch ? Insn_B : 
                       stall_A ? Insn_A :i_cur_insn_A;
    assign input_D_B =  pipe_switch ? i_cur_insn_A : 
                        stall_A ? Insn_B :i_cur_insn_B;

//nzp
    wire [2:0] Is_Zero_A, Is_Zero_B;
    wire [2:0] input_nzp, o_nzp;

    Nbit_reg #(3, 3'b000) nzp (.in(input_nzp), .out(o_nzp), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    assign input_nzp = o_nzp;
    assign Is_Zero_A = input_nzp & XM_A[11:9];


//pc
    wire [15:0] next_pc_A, pc_F_A, input_pc_D_A, pc_X_A, PC_X_A, pc_MW_A, w_o_pc_A; 
    wire [15:0] input_pc_D_B, d2x_pc_B, PC_X_B, pc_MW_B, w_o_pc_B;
    wire [15:0] o_pc_plus_one_F_A, o_pc_plus_two_F_A;

    cla16 pc_incr1(.a(pc_F_A), .b(16'b0), .cin(1'b1), .sum(o_pc_plus_one_F_A));
    cla16 pc_incr2(.a(o_pc_plus_one_F_A), .b(16'b0), .cin(1'b1), .sum(o_pc_plus_two_F_A));
    assign branch_taken_A = ((Is_Zero_A != 3'b0) && (XM_A[17] == 1)) ? 1'b1 : 1'b0;
    assign Is_Zero_B = input_nzp & XM_B[11:9];
    assign branch_taken_B = ((Is_Zero_B != 3'b0) && (XM_B[17] == 1)) ? 1'b1 : 1'b0;
    assign br_ctrl_X_B = branch_taken_B || XM_B[16];
    assign br_ctrl_X_A = branch_taken_A || XM_A[16];
    assign next_pc_A =  br_ctrl_X_A ? o_ALU_A :
                        br_ctrl_X_B ? o_ALU_B : 
                        stall_A ? pc_F_A :
                        pipe_switch ? o_pc_plus_one_F_A :
                        o_pc_plus_two_F_A;    
    assign input_pc_D_A = (pipe_switch) ? d2x_pc_B :  
                      stall_A ? pc_X_A :
                      pc_F_A;
    assign input_pc_D_B = (pipe_switch) ? pc_F_A :  
                      stall_B ? d2x_pc_B :
                      o_pc_plus_one_F_A;
                         
    wire [15:0] o_pc_puls_one_W_A, o_pc_puls_one_W_B;

    cla16 pc_one_A(.a(w_o_pc_A), .b(16'b0), .cin(1'b1), .sum(o_pc_puls_one_W_A));
    cla16 pc_one_B(.a(w_o_pc_B), .b(16'b0), .cin(1'b1), .sum(o_pc_puls_one_W_B));

    assign  W_A = (O_W_A[20]) ? o_pc_puls_one_W_A :
                           (O_W_A[19] == 1) ? o_WD_A: o_W_O_A;
    assign  W_B = (O_W_B[20]) ? o_pc_puls_one_W_B :
                           (O_W_B[19] == 1) ? o_WD_B : o_WO_B;

    Nbit_reg #(16, 16'h8200) f_pc_reg_A (.in(next_pc_A), .out(pc_F_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b0)    d_pc_reg_A (.in(input_pc_D_A), .out(pc_X_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_D_A));
    Nbit_reg #(16, 16'b0)    x_pc_reg_A (.in(pc_X_A), .out(PC_X_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_X_A));
    Nbit_reg #(16, 16'b0)    m_pc_reg_A (.in(PC_X_A), .out(pc_MW_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(1'b0));
    Nbit_reg #(16, 16'b0)    w_pc_reg_A (.in(pc_MW_A), .out(w_o_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(1'b0));

    Nbit_reg #(16, 16'b0)    d_pc_reg_B (.in(input_pc_D_B), .out(d2x_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_D_B));
    Nbit_reg #(16, 16'b0)    x_pc_reg_B (.in(d2x_pc_B), .out(PC_X_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_X_B));
    Nbit_reg #(16, 16'b0)    m_pc_reg_B (.in(PC_X_B), .out(pc_MW_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_M_B));
    Nbit_reg #(16, 16'b0)    w_pc_reg_B (.in(pc_MW_B), .out(w_o_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(1'b0));

// Intermediate Registers for NZP 
    wire [2:0] input_wdata_A, o_nzp_M_A, input_nzp_W_A,input_wdata_B, o_nzp_M_B, input_nzp_W_B;
    wire [2:0] ALU_nzp_A, NZP_A_load, nzp_trap_A,ALU_nzp_B, NZP_B_load, nzp_trap_B;
  
    assign input_nzp_W_A = ((MW_A[19]==1)) ? NZP_A_load : o_nzp_M_A;
    assign ALU_nzp_A = ($signed(o_ALU_A) > 0) ? 3'b001 : 
                       (o_ALU_A == 0) ? 3'b010 : 3'b100;
    assign NZP_A_load = ($signed(i_cur_dmem_data) > 0) ? 3'b001 :
                      (i_cur_dmem_data == 0) ? 3'b010 : 3'b100;  
    assign nzp_trap_A = ($signed(PC_X_A) > 0) ? 3'b001:
                        (PC_X_A == 0) ? 3'b010: 3'b100;  
    assign input_wdata_A = (XM_A[15:12] == 4'b1111) ? nzp_trap_A :  
                        ((MW_A[19] == 1) && (o_stall_X_A == 2'd3)) ? NZP_A_load : ALU_nzp_A;
    
    assign input_nzp_W_B = ((MW_B[19]==1)) ? NZP_B_load : o_nzp_M_B;
    assign ALU_nzp_B = ($signed(o_ALU_B) > 0) ? 3'b001 : 
                       (o_ALU_B == 0) ? 3'b010 : 
                       3'b100;
    assign NZP_B_load = ($signed(i_cur_dmem_data) > 0) ? 3'b001 :
                      (i_cur_dmem_data == 0) ? 3'b010 : 
                      3'b100;  
    assign nzp_trap_B = ($signed(PC_X_B) > 0) ? 3'b001:
                        (PC_X_B == 0) ? 3'b010: 
                        3'b100;  
    assign input_wdata_B = (XM_B[15:12] == 4'b1111) ? nzp_trap_B :  
                                    ((MW_B[19]==1) && (o_stall_X_B == 2'd3)) ? NZP_B_load :   
                                    ALU_nzp_B;
                                    
    Nbit_reg #(3, 3'b0) m_nzp_A (.in(input_wdata_A), .out(o_nzp_M_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b0) w_nzp_A (.in(input_nzp_W_A), .out(test_nzp_new_bits_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'b0) m_nzp_B (.in(input_wdata_B), .out(o_nzp_M_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_M_B));
    Nbit_reg #(3, 3'b0) w_nzp_B (.in(input_nzp_W_B), .out(test_nzp_new_bits_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 

//
    wire [15:0] input_X_A_A, o_X_A_A, input_X_B_A, o_X_B_A,
                o_M_B_A, input_M_O_A, o_M_O_A, 
                o_W_O_A, input_WD_A, o_WD_A;
    wire [15:0] input_X_AB, o_X_AB, input_X_BB, o_X_BB,
                o_M_BB, input_MO_B, o_M_O_B, 
                o_WO_B, input_WD_B, o_WD_B;
    wire [15:0] W_A, W_B;                  // Determine the value that writes back to the Regfiles //
    assign  input_X_A_A = o_rsdata_A;
    assign  input_X_B_A = o_rtdata_A;
    assign  input_X_AB = o_rsdata_B; 
    assign  input_X_BB = o_rtdata_B;
    assign  input_M_O_A = o_ALU_A; 
    assign  input_MO_B = o_ALU_B;       

    Nbit_reg #(16, 16'b0) X_A_A (.in(input_X_A_A), .out(o_X_A_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_X_A));
    Nbit_reg #(16, 16'b0) X_B_A (.in(input_X_B_A), .out(o_X_B_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_X_A));
    Nbit_reg #(16, 16'b0) M_B_A (.in(rt_bypass_A), .out(o_M_B_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b0) M_O_A (.in(input_M_O_A), .out(o_M_O_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b0) W_O_A (.in(o_M_O_A), .out(o_W_O_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b0) W_D_A (.in(i_cur_dmem_data), .out(o_WD_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b0) X_A_B (.in(input_X_AB), .out(o_X_AB), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_X_B));
    Nbit_reg #(16, 16'b0) X_B_B (.in(input_X_BB), .out(o_X_BB), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_X_B));
    Nbit_reg #(16, 16'b0) M_B_B (.in(rt_bypass_B), .out(o_M_BB), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_M_B));
    Nbit_reg #(16, 16'b0) M_O_B (.in(input_MO_B), .out(o_M_O_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst | flush_M_B));
    Nbit_reg #(16, 16'b0) W_O_B (.in(o_M_O_B), .out(o_WO_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b0) W_D_B (.in(i_cur_dmem_data), .out(o_WD_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    

//bypass
    wire rs_MX_BA, rs_MX_AA, rs_WX_BA, rs_WX_AA, 
         rt_MX_BA, rt_MX_AA, rt_WX_BA, rt_WX_AA,
         rs_MX_BB, rs_MX_AB, rs_WX_BB, rs_WX_AB,
         rt_MX_BB, rt_MX_AB, rt_WX_BB, rt_WX_AB;
    
    assign rs_MX_BA = (XM_A[33:31] == MW_B[27:25]) && (MW_B[22] == 1) && (XM_A[24]);
    assign rs_MX_AA = (XM_A[33:31] == MW_A[27:25]) && (MW_A[22] == 1) && (XM_A[24]);
    assign rs_WX_BA = (XM_A[33:31] == O_W_B[27:25]) && (O_W_B[22] == 1) && (XM_A[24]);
    assign rs_WX_AA = (XM_A[33:31] == O_W_A[27:25]) && (O_W_A[22] == 1) && (XM_A[24]);
    
    assign rs_bypass_A = rs_MX_BA ? o_M_O_B :
                             rs_MX_AA ? o_M_O_A :
                             rs_WX_BA ? W_B :
                             rs_WX_AA ? W_A : 
                             o_X_A_A;

    assign rt_MX_BA = (XM_A[30:28] == MW_B[27:25]) && (MW_B[22] == 1) && (XM_A[23]);
    assign rt_MX_AA = (XM_A[30:28] == MW_A[27:25]) && (MW_A[22] == 1) && (XM_A[23]);
    assign rt_WX_BA = (XM_A[30:28] == O_W_B[27:25]) && (O_W_B[22] == 1) && (XM_A[23]);
    assign rt_WX_AA = (XM_A[30:28] == O_W_A[27:25]) && (O_W_A[22] == 1) && (XM_A[23]);

    assign rt_bypass_A = rt_MX_BA ? o_M_O_B :
                             rt_MX_AA ? o_M_O_A :
                             rt_WX_BA ? W_B :
                             rt_WX_AA ? W_A :
                             o_X_B_A;
 
    assign rs_MX_BB = (XM_B[33:31] == MW_B[27:25]) && (MW_B[22] == 1) && (XM_B[24]);
    assign rs_MX_AB = (XM_B[33:31] == MW_A[27:25]) && (MW_A[22] == 1) && (XM_B[24]);
    assign rs_WX_BB = (XM_B[33:31] == O_W_B[27:25]) && (O_W_B[22] == 1) && (XM_B[24]);
    assign rs_WX_AB = (XM_B[33:31] == O_W_A[27:25]) && (O_W_A[22] == 1) && (XM_B[24]);

    assign rs_bypass_B = rs_MX_BB ? o_M_O_B :
                             rs_MX_AB ? o_M_O_A :
                             rs_WX_BB ? W_B :
                             rs_WX_AB ? W_A :
                             o_X_AB;


    assign rt_MX_BB = (XM_B[30:28] == MW_B[27:25]) && (MW_B[22] == 1) && (XM_B[23]);
    assign rt_MX_AB = (XM_B[30:28] == MW_A[27:25]) && (MW_A[22] == 1) && (XM_B[23]);
    assign rt_WX_BB = (XM_B[30:28] == O_W_B[27:25]) && (O_W_B[22] == 1) && (XM_B[23]);
    assign rt_WX_AB = (XM_B[30:28] == O_W_A[27:25]) && (O_W_A[22] == 1) && (XM_B[23]);

    assign rt_bypass_B = rt_MX_BB ? o_M_O_B :
                             rt_MX_AB ? o_M_O_A :
                             rt_WX_BB ? W_B :
                             rt_WX_AB ? W_A :
                             o_X_BB;
  

//memory
    wire [15:0] o_dmem_addr_A, o_dmem_addr_B, o_dmem_W_A, o_dmem_W_B;
    assign o_dmem_addr_A = ((MW_A[19] == 1) || (MW_A[18] == 1)) ? o_M_O_A : 16'b0;
    assign o_dmem_addr_B = ((MW_B[19] == 1) || (MW_B[18] == 1)) ? o_M_O_B : 16'b0;

    assign test_dmem_we_A = O_W_A[18];
    assign test_dmem_we_B = O_W_B[18];

    assign o_dmem_we = MW_A[18] | MW_B[18];
    assign o_dmem_addr = ((MW_A[19] == 1) || (MW_A[18] == 1)) ? o_dmem_addr_A :
                         ((MW_B[19] == 1) || (MW_B[18] == 1)) ? o_dmem_addr_B :
                         16'b0;  

    assign test_dmem_data_A = (O_W_A[19]) ? o_WD_A : 16'b0; 
    assign test_dmem_data_B = (O_W_B[19]) ? o_WD_B : 16'b0;
    
    assign o_dmem_towrite = 16'd0;    

    Nbit_reg #(16, 16'b0)   w_dmem_addr_A (.in(o_dmem_addr_A), .out(test_dmem_addr_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'b0)   w_dmem_addr_B (.in(o_dmem_addr_B), .out(test_dmem_addr_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

  
    lc4_regfile_ss superscaler(.clk(clk),.gwe(gwe),.rst(rst),.i_rs_A(X_div_A[33:31]),.i_rt_A(X_div_A[30:28]),.o_rs_data_A(o_rsdata_A),
        .o_rt_data_A(o_rtdata_A),.i_rs_B(X_div_B[33:31]),.i_rt_B(X_div_B[30:28]),.o_rs_data_B(o_rsdata_B),.o_rt_data_B(o_rtdata_B),
        .i_rd_A(O_W_A[27:25]),.i_wdata_A(W_A),.i_rd_we_A(O_W_A[22]),.i_rd_B(O_W_B[27:25]),.i_wdata_B(W_B),
        .i_rd_we_B(O_W_B[22]));



    // ****** Test Wire Assignment ****** // 
    assign test_cur_pc_A = w_o_pc_A;
    assign test_cur_pc_B = w_o_pc_B;
    assign test_cur_insn_A = O_W_A;
    assign test_cur_insn_B = O_W_B;
    assign test_regfile_we_A = O_W_A[22];
    assign test_regfile_we_B = O_W_B[22];
    assign test_regfile_wsel_A = O_W_A[27:25];
    assign test_regfile_wsel_B = O_W_B[27:25];
    assign test_regfile_data_A =  W_A;
    assign test_regfile_data_B =  W_B;
    assign test_nzp_we_A = O_W_A[21];
    assign test_nzp_we_B = O_W_B[21];

    
   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
always @(posedge gwe) begin

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
      // run it for that many nanoseconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display();
   end
endmodule
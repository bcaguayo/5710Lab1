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
   


   assign led_data = switch_data;
   /*** YOUR CODE HERE ***/

 //____________________________________FETCH___________________________________________

   //getting pc reg stuff
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]  next_pc;

   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
   //calculate pc + 1
   wire [15:0] pc_plus;
   assign pc_plus=pc+1;
//______________________________D Pipeline Register___________________________________
   
   wire [17:0] Input_D, Output_D;
   wire [15:0] O_Insn_D, pc_D;
   Nbit_reg #(16, 0) D_insn_reg (.in(Input_Insn), .out(O_Insn_D), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) D_pc_reg (.in(Input_pc), .out(pc_D), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));   
   Nbit_reg #(18, 0) stage_D (.in(Input_DReal), .out(Output_D), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 0) nop_D (.in(misPredict), .out(o_Nop_D), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   
//___________________________________DECODE___________________________________________

   wire r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;
   wire [2:0] r1sel, r2sel, wsel;
   wire [15:0] o_Rsdata, o_Rtdata, w_data; 
   lc4_decoder decoder(.insn(Input_Insn), .r1sel(r1sel), .r1re(r1re), .r2sel(r2sel), .r2re(r2re), .wsel(wsel), .regfile_we(regfile_we),
   .nzp_we(nzp_we), .select_pc_plus_one(select_pc_plus_one), .is_load(is_load), .is_store(is_store), .is_branch(is_branch), .is_control_insn(is_control_insn));


   assign Input_D[2:0] = r1sel;
   assign Input_D[3] = r1re;
   assign Input_D[6:4] = r2sel;
   assign Input_D[7] = r2re;
   assign Input_D[10:8] = wsel;
   assign Input_D[11] = regfile_we;
   assign Input_D[12] = nzp_we;
   assign Input_D[13] = select_pc_plus_one;
   assign Input_D[14] = is_load;
   assign Input_D[15] = is_store;
   assign Input_D[16] = is_branch;
   assign Input_D[17] = is_control_insn;

   wire Nop_D = misPredict;
   wire o_Nop_D;
   wire [17:0] Input_DReal = (loadToUseStall == 1'b1) ? Output_D : misPredict ? 0 : Input_D;
   wire [15:0] Input_Insn = loadToUseStall ? O_Insn_D : misPredict ? 0 : i_cur_insn;
   wire [15:0] Input_pc = loadToUseStall ? pc_D : pc;

//WD bypass
   assign rsdata_D = (Output_D[2:0] == Output_W[10:8]) & Output_W[11]  ? w_data : o_Rsdata;
   assign rtdata_D = (Output_D[6:4] == Output_W[10:8]) & Output_W[11] ? w_data : o_Rtdata;


   lc4_regfile #(.n(16)) regs (.clk(clk), .rst(rst), 
   .gwe(gwe), .i_rs(Output_D[2:0]), .o_rs_data(o_Rsdata), .i_rt(Output_D[6:4]), 
   .o_rt_data(o_Rtdata), .i_rd(Output_W[10:8]), .i_wdata(w_data), .i_rd_we(Output_W[11]));


//______________________________X Pipeline Register___________________________________

   wire [17:0] Output_X, Input_XReal;
   wire [15:0] O_Insn_X, o_rsdata_X, o_rtdata_X, pc_X, Insn_XReal, pc_XReal;

   Nbit_reg #(16, 0) X_rs_reg (.in(rsdata_D), .out(o_rsdata_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) X_rt_reg (.in(rtdata_D), .out(o_rtdata_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 0) loadtouse_X (.in(loadToUseStallReal), .out(loadToUseOutput_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 0) n_X (.in(Nop_X), .out(O_Nop_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) X_insn_reg (.in(Insn_XReal), .out(O_Insn_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) X_pc_reg (.in(pc_XReal), .out(pc_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) stage_X (.in(Input_XReal), .out(Output_X), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   

//___________________________________EXECUTE__________________________________________

   assign Insn_XReal = Nop_X ? 16'b0000000000000000 : O_Insn_D;
   //assign pc_XReal = Nop_X ? 16'b0000000000000000 : pc_D;
   assign pc_XReal = pc_D;
   assign Input_XReal = Nop_X ? 16'b0000000000000000 : Output_D;

   wire Nop_X, O_Nop_X;
   assign Nop_X = loadToUseStall | misPredict | o_Nop_D;


   //deal with output of the registers 
   wire [15:0] rsdata_D, rtdata_D;

   wire loadToUseOutput_X;

   //load to use pipelining, might need to see if I need to add something on M stage?
   wire loadToUseStall;

   wire SRL = (O_Insn_D[15:12] == 4'b1010) && (!O_Insn_D[4] | !O_Insn_D[5]);
   wire AND = (O_Insn_D[15:12] == 4'b0101) & (O_Insn_D[5]);
   wire ADD = |((O_Insn_D[15:12] == 4'b0001) & (O_Insn_D[5]));   
   wire branch_D = Output_D[16];
   wire NOT = (O_Insn_D[15:12] == 4'b0101) & (O_Insn_D[3] & !O_Insn_D[4]);
   wire CONST = (O_Insn_D[15:12] == 4'b1001); 
   wire HICONST = O_Insn_D[15:12] == 4'b1101;
   wire isControl = Output_D[17];
   wire CMP = (O_Insn_D[15:12] == 4'b0010) & O_Insn_D[8];
   wire JUMP = (O_Insn_D[15:11] == 5'b11001);

   wire Notstore_D = !Output_D[15];
   wire pipeNotStoreAndEqReg = (Output_D[6:4] == Output_X[10:8]);
   assign loadToUseStall = ((Output_X[14]) && ((Output_D[16]) | (((Output_D[2:0] == Output_X[10:8]) & !CONST)
            || ((Output_D[6:4] == Output_X[10:8]) && (Output_D[15] != 1'b1) && !Output_D[14]
             && !AND && !ADD && !SRL && !branch_D && !NOT && 
             !CONST && !HICONST & !CMP & !isControl))) && !JUMP) ;
   

   wire loadToUseStallReal = misPredict ? 0 : loadToUseStall;
   wire loadToUseOutput_M;

//Wx bypassing
   wire [15:0] rsdata;
   assign rsdata = (Output_X[2:0] == Output_M[10:8]) & (Output_M[11]) ? alu_M :
                   (Output_X[2:0] == Output_W[10:8]) & Output_W[11] ? w_data : o_rsdata_X;

   wire [15:0] rtdata;
   assign rtdata = (Output_X[6:4] == Output_M[10:8]) & (Output_M[11]) ? alu_M : 
                   (Output_X[6:4] == Output_W[10:8]) & Output_W[11] ? w_data : o_rtdata_X;

   wire[15:0] o_ALU;
   lc4_alu alu (.i_insn(O_Insn_X), .i_pc(pc_X), .i_r1data(rsdata), .i_r2data(rtdata), .o_result(o_ALU));

   wire[15:0] rtdata_XReal = (Output_X[6:4] == Output_W[10:8]) & (Output_W[11]) ? w_data : 
                            (Output_X[6:4] == Output_M[10:8]) & (Output_M[11]) ? alu_M : o_rtdata_X;

   

   wire [15:0] O_Insn_XReal, pc_XRealo;
   wire [17:0] Output_XReal;
   wire O_Nop_XReal =  O_Nop_X;

   assign O_Insn_XReal = O_Insn_X;
   //assign pc_XRealo = misPredict ? 0 : pc_X;
   assign pc_XRealo = pc_X;
   assign Output_XReal = Output_X;

   wire [15:0] next_pc_X; 
   //get pc plus 1
   assign next_pc_X=pc_X+1;

//______________________________M Pipeline Register___________________________________

   wire O_Nop_M, O_Nop_W;
   wire [15:0] next_pc_M, next_pc_W;
   wire [17:0] Output_M;
   wire [15:0] O_Insn_M, o_rsdata_M, o_Rtdata_M, pc_M, alu_M;
   Nbit_reg #(16, 0) M_insn_reg (.in(O_Insn_XReal), .out(O_Insn_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_pc_reg (.in(pc_XRealo), .out(pc_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_next_pc_reg (.in(next_pc_X), .out(next_pc_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) Mstage (.in(Output_XReal), .out(Output_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 0) M_rs_reg (.in(o_rsdata_X), .out(o_rsdata_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_rt_reg  (.in(rtdata_XReal), .out(o_Rtdata_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) o_alu_M (.in(o_ALU), .out(alu_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 0) loadtouse_M (.in(loadToUseOutput_X), .out(loadToUseOutput_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 0) M_NOP (.in(O_Nop_XReal), .out(O_Nop_M), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

//____________________________________MEMORY__________________________________________
 
   wire loadToUseStallReal_X = misPredict ? 0 : loadToUseOutput_X;
//wm bypass

   assign o_dmem_we = Output_M[15] && !O_Nop_M; 

   assign o_dmem_towrite = (Output_M[6:4] == Output_W[10:8]) && !O_Nop_W && !Output_W[16] && Output_W[11] ? w_data : o_Rtdata_M;

   assign o_dmem_addr = ((Output_M[14] | Output_M[15]) == 1'b1) ? alu_M : 16'd0;
   
   wire [15:0] dataMeme = o_dmem_we ? o_dmem_towrite : Output_M[14] ? i_cur_dmem_data : 0;
   
//______________________________W Pipeline Register___________________________________
   wire loadToUseOutput_W;

   wire [17:0] Output_W;
   wire [15:0] O_Insn_W, o_rsdata_W, o_Rtdata_W, pc_W, alu_W, dmem_towrite_W, Addr_W;
   Nbit_reg #(16, 0) W_insn_reg (.in(O_Insn_M), .out(O_Insn_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_pc_reg (.in(pc_M), .out(pc_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_next_pc_reg (.in(next_pc_M), .out(next_pc_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) Wstage (.in(Output_M), .out(Output_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 0) W_rs_reg (.in(o_rsdata_M), .out(o_rsdata_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_rt_reg (.in(o_Rtdata_M), .out(o_Rtdata_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_alu (.in(alu_M), .out(alu_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) dataGot (.in(dataMeme), .out(dmem_towrite_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) dataAddr (.in(o_dmem_addr), .out(Addr_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 0) loadtouse_W (.in(loadToUseOutput_M), .out(loadToUseOutput_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 0) Nop_W (.in(O_Nop_M), .out(O_Nop_W), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

//__________________________________WRITEBACK_________________________________________

   wire[15:0] regMuxOutput;
   wire[15:0] O_mem_D = (Addr_W != 1'b0) ? dmem_towrite_W : alu_W;


   assign regMuxOutput = (Output_W[13] == 1'b1) ? next_pc_W : O_mem_D;
   assign w_data = regMuxOutput;

   wire[15:0] regMuxOutputFake;
   wire[15:0] O_mem_DFake = Output_M[14] ?  dataMeme : alu_M;
   assign regMuxOutputFake = Output_M[13] ? next_pc_M : O_mem_DFake;

   wire[2:0] nzpf;

   assign nzpf[1] = (regMuxOutputFake == 16'b0000000000000000) ? 1'b1 : 1'b0;
   assign nzpf[0] = ((regMuxOutputFake[15] == 1'b0) && !nzpf[1])? 1'b1 : 1'b0;
   assign nzpf[2] = (regMuxOutputFake[15] == 1'b1) ? 1'b1 : 1'b0;


   wire[15:0] imm9 = O_Insn_X[8] == 1'b1 ? 16'b1111111000000000 | O_Insn_X :
                                         16'b0000000111111111 & O_Insn_X;
   wire[15:0] imm11 = O_Insn_X[10] == 1'b1 ? 16'b1111110000000000 | O_Insn_X :
                                           16'b0000001111111111 & O_Insn_X;

   //nzp stuff
   wire [2:0] next_nzp;

   wire [2:0] nzp = ($signed(regMuxOutput) == 16'd0) ? 3'b010 :
                         (regMuxOutput[15] ==  1'b1) ? 3'b100 : 3'b001;
   Nbit_reg #(3, 3'b000) nzp_reg (.in(nzp), .out(next_nzp), .clk(clk), .we(Output_W[12]), .gwe(gwe), .rst(rst));

   wire [2:0] nzpAndI = next_nzp & O_Insn_X[11:9];

   wire [2:0] nzpAndIbypass = nzp & O_Insn_X[11:9];
   wire [2:0] nzpFake = nzpf & O_Insn_X[11:9];

   wire nzpTest = (Output_M[12] && !O_Nop_M) ? (|nzpFake) : (Output_W[12] && !O_Nop_W) ? |nzpAndIbypass : |nzpAndI;
   wire [15:0] branchMux = (nzpTest) ? o_ALU : pc_plus;

   wire[15:0] nppp = loadToUseStall ? pc : pc_plus;
   wire[15:0] npct = (Output_X[17]) ? o_ALU : nppp;
   assign next_pc = (Output_X[16]) & nzpTest ? branchMux : npct;

   wire misPredict = (Output_X[17] & !O_Nop_X)| (Output_X[16] & nzpTest & !O_Nop_X);


   assign test_nzp_new_bits = nzp;
   assign test_dmem_addr = Addr_W; //need to change once doing other stuff
   assign test_dmem_data = dmem_towrite_W;
   assign test_stall[0] = loadToUseOutput_W;
   assign test_stall[1] = ((O_Insn_W == 0) && (pc_W == 0)) | O_Nop_W ? 1 : 0;
   assign test_nzp_we = Output_W[12];
   assign test_dmem_we = Output_W[15];
   assign test_cur_insn = O_Insn_W;
   assign test_regfile_we = Output_W[11];
   assign test_regfile_wsel = Output_W[10:8];
   assign test_regfile_data = w_data;
   assign o_cur_pc = pc;
   assign test_cur_pc = pc_W;
   
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
      // $display("wsel %h", wsel);
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
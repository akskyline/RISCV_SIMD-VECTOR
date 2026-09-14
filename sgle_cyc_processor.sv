module sgle_cyc_processor(input logic clk, rst);

// intermediate 
logic        zero;
logic regwrite, alu_src, memwrite, branch, jump, pc_src;
logic [1:0] imm_src, result_src;
logic [2:0] ALUControl;
logic [31:0] RD;
logic [31:0] pc, pc_next, instruction, alu_result;
logic [31:0] W_Data;
logic [31:0] RD1,RD2; 
logic [31:0] imm,srcb;
logic [31:0] pcplus_4;

 

//pc_top(combine pc)
pc_top pc_counter1(
    .clk(clk),
    .rst(rst),
    .pc_src(pc_src),    
    .imm(imm),              
    .pc(pc),
    .pcplus_4(pcplus_4),
    .pc_next(pc_next)
);


//Instruction memory
ins_mem ins_mem2(
    .addr(pc),
    .instruction(instruction)
);


// control unit
control_unit cu3(
    .ins       (instruction),
    .zero      (zero),
    .regwrite  (regwrite),
    .alu_src   (alu_src),
    .memwrite  (memwrite),
    .result_src(result_src),
    .imm_src   (imm_src),
    .branch    (branch),
    .jump      (jump),
    .pc_src    (pc_src),
    .ALUControl(ALUControl)
);


//register file
register_file reg_file4(
    .clk(clk),
    .regwrite(regwrite),
    .instruction(instruction),
    .WD_reg(W_Data),
    .RD1(RD1),
    .RD2(RD2)
);

imm_data immdata5(
    .ins(instruction),
    .imm_src(imm_src),
    .imm(imm)
);

alu_mux alu_mux6(
    .RD2(RD2),
    .imm(imm),
    .alu_src(alu_src),
    .srcb(srcb)
);

alu alu7(
    .RD1(RD1),
    .srcb(srcb),
    .ALUControl(ALUControl),
    .alu_result(alu_result),
    .zero(zero)
);


data_mem data_mem8(
    .clk(clk),
    .memwrite(memwrite),
    .A(alu_result),
    .WD(RD2),
    .RD(RD)
);


memtoreg_mux_3to1 mux_ressult9(
    .alu_result(alu_result),
    .RD(RD),
    .result_src(result_src),
    .PCPlus4(pcplus_4),
    .WD(W_Data)
    
);
endmodule




//testbench
module sgle_cyc_processor_tb();
reg clk,rst;

sgle_cyc_processor dut(
.clk(clk),
.rst(rst)
);

initial 
clk = 0;
always #5 clk =~clk;
  initial begin
    rst = 1;
    #10;
    rst = 0;
repeat (10) @(posedge clk);
$finish;
  end
endmodule

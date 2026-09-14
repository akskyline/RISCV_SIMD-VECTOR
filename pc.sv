// program counter module
module program_counter(
    input  logic        clk,rst,
    input  logic [31:0] pc_next,
    output logic [31:0] pc
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'h00000000;    // initial address
        else
            pc <= pc_next;
    end
endmodule

//Alu_pc, pc + 4
module alu_pc(
    input  logic [31:0] pc,
    output logic [31:0] pcplus_4
);
    assign pcplus_4 = pc + 32'd4;
endmodule

// ALU for branch 
module alu_pc_target(
    input  logic [31:0] pc,       
    input  logic [31:0] imm,   
    output logic [31:0] pc_target 
);
    assign pc_target = pc + imm;
endmodule

//pc mux2_1
module pc_src_mux(
    input  logic [31:0] pcplus_4, pc_target,
    input  logic        pc_src,
    output logic [31:0] pc_next
);
    assign pc_next = (pc_src) ? pc_target : pcplus_4;
endmodule

//pc_top(combine pc)
module pc_top(
    input  logic        clk, rst, pc_src,    
    input  logic [31:0] imm,              
    output logic [31:0] pc,
    output logic [31:0] pcplus_4,
    output logic [31:0] pc_next
);

    // Internal signal

    logic [31:0] pc_target;

    // 1. Program Counter Register
    program_counter pc_current (
        .clk(clk),
        .rst(rst),
        .pc_next(pc_next),
        .pc(pc)
    );

    // 2. ALU for PC + 4
    alu_pc pc_adder_4 (
        .pc(pc),
        .pcplus_4(pcplus_4)
    );

    // 3. ALU for PC + Immediate (Branch Target)
    alu_pc_target pc_target_alu (
        .pc(pc),
        .imm(imm),
        .pc_target(pc_target)
    );

    // 4. MUX for selecting next PC
    pc_src_mux pc_mux (
        .pcplus_4(pcplus_4),      
        .pc_target(pc_target),  
        .pc_src(pc_src),
        .pc_next(pc_next)
    );

endmodule

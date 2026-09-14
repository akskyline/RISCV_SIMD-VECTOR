// MUX:  for ALU Side (RD2 or immediate)
module alu_mux(
    input  logic [31:0] RD2,    // register file output 
    input  logic [31:0] imm,    // immediate from imm_ext
    input  logic  alu_src,      // control: 0 -> RD2, 1 -> imm
    output logic [31:0] srcb    // ALU second operand 
);
    assign srcb = (alu_src) ? imm : RD2;
endmodule

// ALU
module alu(
    input  logic [31:0] RD1, srcb,
    input  logic [2:0]  ALUControl,
    output logic [31:0] alu_result,
    output logic        zero
);

    always_comb
        case (ALUControl)
            3'b000: alu_result = RD1 + srcb;            // ADD
            3'b001: alu_result = RD1 - srcb;            // SUB
            3'b010: alu_result = RD1 & srcb;            // AND
            3'b011: alu_result = RD1 | srcb;            // OR
            3'b101: alu_result = (RD1 < srcb) ? 32'd1 : 32'd0; // SLT
            default: alu_result = 32'hxxxxxxxx;
        endcase 

    assign zero = (RD1 == srcb) ? 1'b1 : 1'b0;  
endmodule



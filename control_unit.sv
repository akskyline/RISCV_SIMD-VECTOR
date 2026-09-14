//Main Decoder
module main_decoder (
    input logic [31:0] ins, 
    input logic  zero,     
    output logic [1:0] imm_src, alu_op, result_src,    
    output logic regwrite, alu_src, memwrite, branch, jump, pc_src); 

logic [6:0] opcode;
assign opcode = ins[6:0];
logic [10:0] controls;

always_comb
case (opcode)
7'b0000011: controls = 11'b1_00_1_0_01_0_00_0;  //LW
7'b0100011: controls = 11'b0_01_1_1_xx_0_00_0;  //SW
7'b0110011: controls = 11'b1_xx_0_0_00_0_10_0;  //R-type
7'b1100011: controls = 11'b0_10_0_0_xx_1_01_0;  //Beq
7'b0010011: controls = 11'b1_00_1_0_00_0_10_0;  //addi
7'b1101111: controls = 11'b1_11_x_0_10_0_xx_1;  //Jal
default:    controls = 11'bx_xx_x_x_xx_x_xx_x;  
endcase

assign {regwrite, imm_src, alu_src, memwrite, result_src, branch, alu_op, jump} = controls;

assign pc_src = (zero && branch)|jump;

endmodule

//ALU Decorder
module alu_decoder_3bit (
    input  logic [1:0] alu_op,      // from main control unit
    input  logic [31:0] ins,  
    output logic [2:0] ALUControl  // 3-bit control signal to ALU
);
logic [6:0] opcode;
logic [2:0] funct3;
logic [6:0] funct7;
assign opcode = ins[6:0];
assign funct3 = ins[14:12];
assign funct7 = ins[31:25];
    always_comb 
        case (alu_op)
            2'b00: ALUControl = 3'b000; // Load/store -> ADD
            2'b01: ALUControl = 3'b001; // Branch -> SUB
            2'b10: begin                // R-type instructions
                case (funct3)
                    3'b000: ALUControl = (opcode[5] & funct7[5])?3'b001: 3'b000; // sub , add
                    3'b010: ALUControl = 3'b101; // slt
                    3'b110: ALUControl = 3'b011; // or
                    3'b111: ALUControl = 3'b010; // and
                    default:ALUControl = 3'bxxx; // Default 
                endcase
                end
            default: ALUControl = 3'bxxx;
        endcase
endmodule



//Control Unit using above two sub prts(alu and main decoder)
module control_unit (
    input  logic [31:0] ins,     // bits [31:25]
    input  logic       zero,
    output logic [2:0] ALUControl, // from ALU decoder
    output logic [1:0] imm_src, result_src,
    output logic       regwrite,
    output logic       alu_src,
    output logic       memwrite,
    output logic       branch,
    output logic       jump,
    output logic       pc_src
);

    // Internal connection
    logic [1:0] alu_op;

    // Instantiate Main Decoder
    main_decoder MAIN_DEC (
        .ins      (ins),
        .zero      (zero),
        .regwrite (regwrite),
        .alu_src   (alu_src),
        .memwrite  (memwrite),
        .result_src(result_src),
        .imm_src   (imm_src),
        .branch    (branch),
        .jump      (jump),
        .alu_op    (alu_op),
        .pc_src    (pc_src)
    );

    // Instantiate ALU Decoder
    alu_decoder_3bit ALU_DEC (
        .alu_op     (alu_op),
        .ins        (ins),
        .ALUControl (ALUControl)
    );

endmodule

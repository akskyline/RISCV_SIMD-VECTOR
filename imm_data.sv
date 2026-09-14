// Immediate Extractor
module imm_data(input  logic [31:0] ins,
    input  logic [1:0]  imm_src,
    output logic [31:0] imm);
always_comb
case (imm_src)    
 2'b00: imm = {{20{ins[31]}}, ins[31:20]};                                     // I-type
 2'b01: imm = {{20{ins[31]}}, ins[31:25], ins[11:7]};                          // S-type
 2'b10: imm = {{19{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};   // B-type
 2'b11: imm = {{11{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0}; // J-type
 default: imm = 32'bx;
 endcase
endmodule  





// DATA MEMORY 
module data_mem(
    input  logic        clk, memwrite,
    input  logic [31:0] A,      // address (from ALU)
    input  logic [31:0] WD,     // write data (from register file)
    output logic [31:0] RD      // read data (to register file)
);
    logic [7:0] memory [0:65535]; // 65536 bytes of memory

    // READ
    assign RD = {memory[A+3], memory[A+2], memory[A+1], memory[A]};

    // WRITE
    always_ff @(posedge clk)
        if (memwrite) begin
            memory[A+3]   <= WD[31:24];
            memory[A+2]   <= WD[23:16];
            memory[A+1]   <= WD[15:8];
            memory[A]     <= WD[7:0];
        end
endmodule



// 3-to-1 MUX: select data to write back to register file
module memtoreg_mux_3to1(
    input  logic [31:0] alu_result,    // ALU output
    input  logic [31:0] RD,            // Data read from data memory
    input  logic [31:0] PCPlus4,       // PC+4 for jal/jalr
    input  logic [1:0]  result_src,    // 2-bit control: 00=ALU, 01=Mem, 10=PC+4
    output logic [31:0] WD             // Write data to register file
);

    always_comb begin
        case (result_src)
            2'b00: WD = alu_result;   // ALU instructions
            2'b01: WD = RD;           // Load instructions from memory
            2'b10: WD = PCPlus4;      // jal/jalr instructions
            default:WD = 32'hxxxxxxxx;      // safe default
        endcase
    end

endmodule





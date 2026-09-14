//Register file(32x32)
module register_file(
    input  logic  clk, regwrite, 
    input  logic [31:0] instruction,
    input  logic [31:0] WD_reg,
    output logic [31:0] RD1, RD2
);
    logic [4:0] A1, A2, A3;
    assign A1 = instruction[19:15]; //A1, A2 = source register, A3 = destination register
    assign A2 = instruction[24:20];
    assign A3 = instruction[11:7];

    logic [31:0] regfile [31:0];   // 32 registers, 32 bits each

  // WRITE 
    always_ff @(posedge clk) 
        begin
        if (regwrite)
            regfile[A3] <= WD_reg;   
         end
    
    // READ 
    assign RD1 = (A1 != 5'd0)? regfile[A1] : 0;
    assign RD2 = (A2 != 5'd0)? regfile[A2] : 0;

  endmodule


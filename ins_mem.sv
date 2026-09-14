//instruction memory module
module ins_mem(input logic [31:0] addr,
output logic [31:0] instruction);

logic [7:0] ins_mem [4095:0];
//[addr] [data]
//018 FE420AE3
//014 0062E233
//010 0064A423
//00C FFC4A303
//008 FE54AE23
//004 00500293
//000 00900493

initial begin
$readmemb("./ins.bin",ins_mem); //("file", array_name, start_addr, end_addr)
end
assign instruction = {ins_mem[addr], ins_mem[addr+1], ins_mem[addr+2], ins_mem[addr+3]}; 
endmodule 

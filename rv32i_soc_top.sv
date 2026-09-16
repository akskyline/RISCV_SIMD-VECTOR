// ============================================================================
// File: rv32i_soc_top.sv
// Description: Synthesizable RV32I Single-Cycle Core, SRAMs & MMIO Interconnect
// ============================================================================

// ----------------------------------------------------------------------------
// 1. Instruction Memory (ROM / SRAM)
// ----------------------------------------------------------------------------
module instruction_memory (
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    logic [31:0] rom [0:1023]; // 4KB IMEM

    initial begin
        $readmemh("program.hex", rom);
    end

    // Asynchronous word-aligned read
    assign instr = rom[addr[11:2]]; 
endmodule

// ----------------------------------------------------------------------------
// 2. Data Memory (SRAM)
// ----------------------------------------------------------------------------
module data_memory (
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        we,
    output logic [31:0] rdata
);
    logic [31:0] ram [0:1023]; // 4KB DMEM

    always_ff @(posedge clk) begin
        if (we) begin
            ram[addr[11:2]] <= wdata;
        end
    end

    assign rdata = ram[addr[11:2]];
endmodule

// ----------------------------------------------------------------------------
// 3. RV32I Single-Cycle Core
// ----------------------------------------------------------------------------
module rv32i_core (
    input  logic        clk,
    input  logic        rst_n,
    
    // Instruction Memory Interface
    output logic [31:0] pc_out,
    input  logic [31:0] instr,
    
    // Data/Peripheral Memory Interface
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic        mem_we,
    output logic        mem_re,
    input  logic [31:0] mem_rdata
);
    logic [31:0] pc, next_pc;

    // Instruction Decode Fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // Immediate Decoding
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

    // Register File
    logic [31:0] regfile [0:31];
    logic [31:0] rs1_data, rs2_data, rd_data;
    logic        reg_write;

    assign rs1_data = (rs1 == 5'd0) ? 32'd0 : regfile[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 32'd0 : regfile[rs2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 32; i++) regfile[i] <= 32'd0;
        end else if (reg_write && (rd != 5'd0)) begin
            regfile[rd] <= rd_data;
        end
    end

    // ALU & Control Logic
    logic [31:0] alu_result;
    logic        zero;
    assign zero = (alu_result == 32'd0);

    always_comb begin
        mem_we    = 1'b0;
        mem_re    = 1'b0;
        reg_write = 1'b0;
        next_pc   = pc + 32'd4;
        rd_data   = 32'd0;
        alu_result = 32'd0;

        case (opcode)
            7'b0110011: begin // R-Type
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_result = (funct7 == 7'b0100000) ? (rs1_data - rs2_data) : (rs1_data + rs2_data);
                    3'b111: alu_result = rs1_data & rs2_data;
                    3'b110: alu_result = rs1_data | rs2_data;
                    3'b100: alu_result = rs1_data ^ rs2_data;
                    3'b010: alu_result = ($signed(rs1_data) < $signed(rs2_data)) ? 32'd1 : 32'd0;
                    default: alu_result = 32'd0;
                endcase
                rd_data = alu_result;
            end

            7'b0010011: begin // I-Type Arithmetic
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_result = rs1_data + imm_i;
                    3'b111: alu_result = rs1_data & imm_i;
                    3'b110: alu_result = rs1_data | imm_i;
                    3'b100: alu_result = rs1_data ^ imm_i;
                    default: alu_result = rs1_data + imm_i;
                endcase
                rd_data = alu_result;
            end

            7'b0000011: begin // Load (LW)
                mem_re     = 1'b1;
                reg_write  = 1'b1;
                alu_result = rs1_data + imm_i;
                rd_data    = mem_rdata;
            end

            7'b0100011: begin // Store (SW)
                mem_we     = 1'b1;
                alu_result = rs1_data + imm_s;
            end

            7'b1100011: begin // Branch (BEQ / BNE)
                alu_result = rs1_data - rs2_data;
                if ((funct3 == 3'b000 && zero) || (funct3 == 3'b001 && !zero)) begin
                    next_pc = pc + imm_b;
                end
            end

            7'b0110111: begin // LUI
                reg_write = 1'b1;
                rd_data   = imm_u;
            end

            7'b1101111: begin // JAL
                reg_write = 1'b1;
                rd_data   = pc + 32'd4;
                next_pc   = pc + imm_j;
            end

            default: ;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 32'd0;
        else        pc <= next_pc;
    end

    assign pc_out    = pc;
    assign mem_addr  = alu_result;
    assign mem_wdata = rs2_data;
endmodule

// ----------------------------------------------------------------------------
// 4. Synthesizable SoC Top Wrapper & Address Decoder
// ----------------------------------------------------------------------------
module soc_top (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] current_pc,
    output logic [31:0] last_mem_rdata
);
    wire [31:0] pc_wire;
    wire [31:0] instr_wire;
    wire [31:0] core_mem_addr;
    wire [31:0] core_mem_wdata;
    wire        core_mem_we;
    wire        core_mem_re;
    wire [31:0] core_mem_rdata;

    // Address Decoding (MMIO at 0x8000_0000)
    wire is_coproc_addr = (core_mem_addr[31:28] == 4'h8);

    wire sram_we = core_mem_we & ~is_coproc_addr;
    wire sram_re = core_mem_re & ~is_coproc_addr;

    wire vcop_we = core_mem_we & is_coproc_addr;
    wire vcop_re = core_mem_re & is_coproc_addr;

    wire [31:0] sram_rdata;
    wire [31:0] vcop_rdata;

    assign core_mem_rdata = is_coproc_addr ? vcop_rdata : sram_rdata;
    assign current_pc      = pc_wire;
    assign last_mem_rdata  = core_mem_rdata;

    rv32i_core cpu_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .pc_out     (pc_wire),
        .instr      (instr_wire),
        .mem_addr   (core_mem_addr),
        .mem_wdata  (core_mem_wdata),
        .mem_we     (core_mem_we),
        .mem_re     (core_mem_re),
        .mem_rdata  (core_mem_rdata)
    );

    instruction_memory imem (
        .addr  (pc_wire),
        .instr (instr_wire)
    );

    data_memory dmem (
        .clk   (clk),
        .addr  (core_mem_addr),
        .wdata (core_mem_wdata),
        .we    (sram_we),
        .rdata (sram_rdata)
    );

    vector_coproc #(
        .VLEN_WORDS(8),
        .VREG_NUM(8)
    ) coproc_unit (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (core_mem_addr[11:0]),
        .wdata (core_mem_wdata),
        .wren  (vcop_we),
        .rden  (vcop_re),
        .rdata (vcop_rdata)
    );
endmodule
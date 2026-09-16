// ============================================================================
// File: vector_coproc.sv
// Description: Synthesizable 256-bit Memory-Mapped Vector/SIMD Coprocessor
// ============================================================================

module vector_coproc #(
    parameter VLEN_WORDS = 8, // 8 x 32-bit words = 256 bits per vector register
    parameter VREG_NUM   = 8  // 8 Vector Registers (VREG0 - VREG7)
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic [11:0] addr,  // Local 12-bit address offset
    input  logic [31:0] wdata,
    input  logic        wren,
    input  logic        rden,
    output logic [31:0] rdata
);
    // Address Offset Definitions
    localparam CMD_OFFSET    = 12'h000;
    localparam STATUS_OFFSET = 12'h004;
    localparam VREG_BASE     = 12'h100;
    localparam VREG_TOP      = 12'h1FF;

    // Supported Opcodes
    localparam OP_ADD    = 3'd0;
    localparam OP_MUL    = 3'd1;
    localparam OP_CMP    = 3'd2;
    localparam OP_REDSUM = 3'd3;

    typedef enum logic [1:0] {S_IDLE, S_RUN} state_t;
    state_t state;

    // Vector Register File (8 Registers x 8 Words x 32 Bits)
    logic [31:0] vreg_file [0:VREG_NUM-1][0:VLEN_WORDS-1];

    // Control Registers
    logic [2:0]  opcode_r, src1_r, src2_r, dst_r;
    logic [3:0]  vlen_r;
    logic [2:0]  elem_cnt;
    logic [31:0] accum;

    // Status Signals
    logic busy, done, err;
    logic cmd_start;
    logic op_valid, vlen_valid;

    assign op_valid   = (wdata[2:0] <= OP_REDSUM);
    assign vlen_valid = (wdata[15:12] >= 4'd1) && (wdata[15:12] <= VLEN_WORDS[3:0]);

    // VREG Window Address Decoding Helper
    logic in_vreg_window;
    logic [5:0] vreg_index;
    logic [2:0] sel_reg, sel_word;

    assign in_vreg_window = (addr >= VREG_BASE) && (addr <= VREG_TOP);
    assign vreg_index     = (addr - VREG_BASE) >> 2;
    assign sel_reg        = vreg_index[5:3];
    assign sel_word       = vreg_index[2:0];

    // Command Decode Registering
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_start <= 1'b0;
            opcode_r  <= 3'd0;
            src1_r    <= 3'd0;
            src2_r    <= 3'd0;
            dst_r     <= 3'd0;
            vlen_r    <= 4'd0;
        end else begin
            cmd_start <= 1'b0;
            if (wren && (addr == CMD_OFFSET)) begin
                opcode_r  <= wdata[2:0];
                src1_r    <= wdata[5:3];
                src2_r    <= wdata[8:6];
                dst_r     <= wdata[11:9];
                vlen_r    <= wdata[15:12];
                cmd_start <= 1'b1;
            end
        end
    end

    // FSM & Execution Engine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            busy     <= 1'b0;
            done     <= 1'b0;
            err      <= 1'b0;
            elem_cnt <= 3'd0;
            accum    <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    // Write directly into VREG memory window when CPU issues store
                    if (wren && in_vreg_window) begin
                        vreg_file[sel_reg][sel_word] <= wdata;
                    end

                    if (cmd_start) begin
                        done <= 1'b0;
                        if (!op_valid || !vlen_valid) begin
                            err  <= 1'b1;
                            done <= 1'b1;
                            busy <= 1'b0;
                        end else begin
                            err      <= 1'b0;
                            busy     <= 1'b1;
                            elem_cnt <= 3'd0;
                            accum    <= 32'd0;
                            state    <= S_RUN;
                        end
                    end
                end

                S_RUN: begin
                    case (opcode_r)
                        OP_ADD:    vreg_file[dst_r][elem_cnt] <= vreg_file[src1_r][elem_cnt] + vreg_file[src2_r][elem_cnt];
                        OP_MUL:    vreg_file[dst_r][elem_cnt] <= vreg_file[src1_r][elem_cnt] * vreg_file[src2_r][elem_cnt];
                        OP_CMP:    vreg_file[dst_r][elem_cnt] <= (vreg_file[src1_r][elem_cnt] > vreg_file[src2_r][elem_cnt]) ? 32'd1 : 32'd0;
                        OP_REDSUM: accum                       <= accum + vreg_file[src1_r][elem_cnt];
                        default: ;
                    endcase

                    if (elem_cnt == (vlen_r - 1'b1)) begin
                        if (opcode_r == OP_REDSUM) begin
                            vreg_file[dst_r][0] <= accum + vreg_file[src1_r][elem_cnt];
                        end
                        busy  <= 1'b0;
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        elem_cnt <= elem_cnt + 3'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Read Data Multiplexer
    always_comb begin
        rdata = 32'd0;
        if (rden) begin
            if (addr == STATUS_OFFSET) begin
                rdata = {29'd0, err, done, busy};
            end else if (in_vreg_window) begin
                rdata = vreg_file[sel_reg][sel_word];
            end
        end
    end
endmodule
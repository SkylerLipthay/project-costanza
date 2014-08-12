`include "registers.vh"
`include "instructions.vh"
`include "memory_access.vh"

module cpu(
  clk,
  res,

  mem_addr,
  mem_cs,
  mem_wr,
  mem_acc,
  mem_burst,
  mem_dout,
  mem_din,
  mem_ack,
  mem_lsb_mask_en,

  joypad_1,
  joypad_2,

  framebuffer,
  vblank,

  track_1_addr,
  track_1_length,
  track_1_loop,
  track_1_wr,
  track_1_start,
  track_1_stop,

  track_2_addr,
  track_2_length,
  track_2_loop,
  track_2_wr,
  track_2_start,
  track_2_stop
);

input clk;
input res;

output reg [31:0] mem_addr;
output reg mem_cs;
output reg mem_wr;
output reg [1:0] mem_acc;
output reg [8:0] mem_burst;
output reg [31:0] mem_din;
input [31:0] mem_dout;
input mem_ack;
output reg mem_lsb_mask_en;

input [11:0] joypad_1;
input [11:0] joypad_2;

output reg framebuffer;
input vblank;

output reg [31:0] track_1_addr;
output reg [31:0] track_1_length;
output reg track_1_loop;
output reg track_1_wr;
output reg track_1_start;
output reg track_1_stop;

output reg [31:0] track_2_addr;
output reg [31:0] track_2_length;
output reg track_2_loop;
output reg track_2_wr;
output reg track_2_start;
output reg track_2_stop;

`define STATE_FETCH 4'b0000
`define STATE_FETCHING 4'b0001
`define STATE_READING 4'b0010
`define STATE_WRITING 4'b0011
`define STATE_ARITHMETIC 4'b0100
`define STATE_ARITHMETIC_FIXED 4'b0101
`define STATE_IDLE 4'b0110
`define STATE_READ_LINE 4'b0111
`define STATE_WRITE_LINE 4'b1000

wire [31:0] framebuffer_addr;
// invert the framebuffer pointer so we draw to the inactive buffer while the
// other one is being drawn to screen
assign framebuffer_addr = ~framebuffer ? 32'hFED400 : 32'hFDA800;

reg [3:0] state;
reg [15:0] registers [0:15];
reg [31:0] program_counter;
reg [31:0] stack_pointer;
reg flag_zero;
reg flag_carry;
reg flag_overflow;
reg flag_sign;
reg [16:0] temp;
reg [7:0] working_opcode;
reg [3:0] working_reg_a;
reg [3:0] working_reg_b;

wire [7:0] opcode;
wire [3:0] reg_a;
wire [3:0] reg_b;
wire [15:0] reg_va;
wire [15:0] reg_vb;
wire [15:0] value;
wire [31:0] memory_pointer;

reg [8:0] image_width;
reg [8:0] image_height;
reg [9:0] image_x;
reg [9:0] image_y;
reg [8:0] image_line;
reg [8:0] image_line_dst;

wire [8:0] image_start_x_src;
assign image_start_x_src = image_x[9] ? image_x[8:0] : 9'd0;
wire [8:0] image_start_x;
assign image_start_x = ~image_x[9] ? image_x[8:0] : 9'd0;

assign opcode = mem_dout[31:24];
assign reg_a = mem_dout[23:20];
assign reg_b = mem_dout[19:16];
assign reg_va = registers[reg_a];
assign reg_vb = registers[reg_b];
assign value = mem_dout[15:0];
assign memory_pointer = {registers[`REG_MH], registers[`REG_ML]};

task initial_fetch;
  begin
    mem_addr <= program_counter;
    mem_cs <= 1'b1;
    mem_wr <= 1'b0;
    mem_acc <= `ACC_DWORD;
    state <= `STATE_FETCHING;
  end
endtask

task next_fetch;
  begin
    initial_fetch;
    program_counter <= program_counter + 32'd1;
    mem_addr <= program_counter + 32'd1;
  end
endtask

task next_fetch_two;
  begin
    initial_fetch;
    program_counter <= program_counter + 32'd2;
    mem_addr <= program_counter + 32'd2;
  end
endtask

task next_fetch_set_pc;
  begin
    initial_fetch;
    program_counter <= memory_pointer;
    mem_addr <= memory_pointer;
  end
endtask

task goto_arithmetic;
  begin
    program_counter <= program_counter;
    mem_addr <= mem_addr;
    mem_cs <= 1'b0;
    state <= `STATE_ARITHMETIC;
  end
endtask

task goto_arithmetic_fixed;
  begin
    goto_arithmetic;
    state <= `STATE_ARITHMETIC_FIXED;
  end
endtask

integer index;
reg [15:0] glitch /* synthesis noprune */;

always @(posedge clk) begin
  if (glitch < 16'hFFFF) begin
    glitch <= glitch + 16'd1;
  end

  mem_cs <= 1'b0;
  track_1_wr <= 1'b0;
  track_1_start <= 1'b0;
  track_1_stop <= 1'b0;
  track_2_wr <= 1'b0;
  track_2_start <= 1'b0;
  track_2_stop <= 1'b0;

  registers[`REG_J1] <= {4'd0, joypad_1};
  registers[`REG_J2] <= {4'd0, joypad_2};
  registers[`REG_0] <= 16'd0;
  registers[`REG_1] <= 16'd1;

  if (res) begin
    framebuffer <= 1'b0;
    state <= `STATE_FETCH;
    program_counter <= 32'd0;
    flag_zero <= 1'b0;
    flag_carry <= 1'b0;
    flag_overflow <= 1'b0;
    flag_sign <= 1'b0;
    mem_lsb_mask_en <= 1'b0;
    stack_pointer <= 32'hFDA800;

    for (index = 0; index < 16; index = index + 1) begin
      registers[index] <= 16'd0;
    end
  end else begin
    case (state)
      `STATE_IDLE: begin
        if (vblank) begin
          initial_fetch;
        end
      end

      `STATE_FETCH: begin
        initial_fetch;
      end

      `STATE_FETCHING: begin
        if (mem_ack) begin
          // by default, advance to the next instruction
          next_fetch;

          working_opcode <= opcode;
          working_reg_a <= reg_a;
          working_reg_b <= reg_b;

          case (opcode)
            `INS_MOV_REG: begin
              registers[reg_a] <= registers[reg_b];
            end

            `INS_MOV_LIT: begin
              registers[reg_a] <= value;
              next_fetch_two;
            end

            `INS_LD: begin
              program_counter <= program_counter;
              mem_addr <= memory_pointer;
              mem_wr <= 1'b0;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_WORD;
              state <= `STATE_READING;
            end

            `INS_ST: begin
              program_counter <= program_counter;
              mem_addr <= memory_pointer;
              mem_wr <= 1'b1;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_WORD;
              state <= `STATE_WRITING;
              mem_din <= registers[reg_a];
            end

            `INS_LEA: begin
              program_counter <= program_counter;
              mem_addr <= memory_pointer;
              mem_wr <= 1'b0;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_DWORD;
              state <= `STATE_READING;
            end

            `INS_BR: begin
              next_fetch_set_pc;
            end

            `INS_BRL: begin
              if (flag_sign != flag_overflow) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRLE: begin
              if (flag_zero || flag_sign != flag_overflow) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRG: begin
              if (!flag_zero || flag_sign == flag_overflow) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRGE: begin
              if (flag_sign == flag_overflow) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRE: begin
              if (flag_zero) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRNE: begin
              if (!flag_zero) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRB: begin
              if (flag_carry) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRBE: begin
              if (flag_zero || flag_carry) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRA: begin
              if (!(flag_zero && flag_carry)) begin
                next_fetch_set_pc;
              end
            end

            `INS_BRAE: begin
              if (!flag_carry) begin
                next_fetch_set_pc;
              end
            end

            `INS_ADD: begin
              temp <= reg_va + reg_vb;
              goto_arithmetic;
            end

            `INS_SUB: begin
              temp <= reg_va - reg_vb;
              goto_arithmetic;
            end

            `INS_AND: begin
              registers[reg_a] <= reg_va & reg_vb;
              goto_arithmetic_fixed;
            end

            `INS_OR: begin
              registers[reg_a] <= reg_va | reg_vb;
              goto_arithmetic_fixed;
            end

            `INS_XOR: begin
              registers[reg_a] <= reg_va ^ reg_vb;
              goto_arithmetic_fixed;
            end

            `INS_NOT: begin
              registers[reg_a] <= ~reg_va;
              goto_arithmetic_fixed;
            end

            `INS_CMP: begin
              temp <= reg_va - reg_vb;
              goto_arithmetic;
            end

            `INS_SHL: begin
              registers[reg_a] <= reg_va << 1;
              goto_arithmetic_fixed;
            end

            `INS_SHR: begin
              registers[reg_a] <= reg_va >> 1;
              goto_arithmetic_fixed;
            end

            `INS_RL: begin
              registers[reg_a] <= {reg_va[14:0], reg_va[15]};
              goto_arithmetic_fixed;
            end

            `INS_RR: begin
              registers[reg_a] <= {reg_va[0], reg_va[15:1]};
              goto_arithmetic_fixed;
            end

            `INS_NEG: begin
              registers[reg_a] <= ~reg_va + 16'd1;
              goto_arithmetic_fixed;
            end

            `INS_ADDMA: begin
              {registers[`REG_MH], registers[`REG_ML]} <= memory_pointer + value;
              next_fetch_two;
            end

            `INS_SUBMA: begin
              {registers[`REG_MH], registers[`REG_ML]} <= memory_pointer - value;
              next_fetch_two;
            end

            `INS_SSP: begin
              stack_pointer <= memory_pointer;
            end

            `INS_PUSH: begin
              program_counter <= program_counter;
              mem_addr <= stack_pointer - 32'd1;
              stack_pointer <= stack_pointer - 32'd1;
              mem_wr <= 1'b1;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_WORD;
              state <= `STATE_WRITING;
              mem_din <= registers[reg_a];
            end

            `INS_POP: begin
              program_counter <= program_counter;
              mem_addr <= stack_pointer;
              stack_pointer <= stack_pointer + 32'd1;
              mem_wr <= 1'b0;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_WORD;
              state <= `STATE_READING;
            end

            `INS_CALL: begin
              program_counter <= program_counter;
              mem_addr <= stack_pointer - 32'd2;
              stack_pointer <= stack_pointer - 32'd2;
              mem_wr <= 1'b1;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_DWORD;
              state <= `STATE_WRITING;
              mem_din <= program_counter + 32'd1;
            end

            `INS_RET: begin
              program_counter <= program_counter;
              mem_addr <= stack_pointer;
              stack_pointer <= stack_pointer + 32'd2;
              mem_wr <= 1'b0;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_DWORD;
              state <= `STATE_READING;
            end

            `INS_LSP: begin
              {registers[`REG_MH], registers[`REG_ML]} <= stack_pointer;
            end

            `INS_NOP: begin
            end

            `INS_HALT: begin
              mem_cs <= 1'b0;
              state <= `STATE_IDLE;
            end

            `INS_HRD: begin
              program_counter <= program_counter;
              mem_addr <= memory_pointer;
              mem_wr <= 1'b0;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_BURST;
              mem_burst <= mem_dout[8:0];
              state <= `STATE_READING;
            end

            `INS_HWR: begin
              program_counter <= program_counter;
              mem_addr <= memory_pointer;
              mem_wr <= 1'b1;
              mem_cs <= 1'b1;
              mem_acc <= `ACC_BURST;
              mem_burst <= mem_dout[8:0];
              state <= `STATE_WRITING;
            end

            `INS_SNDA: begin
              if (~mem_dout[16]) begin
                track_1_addr <= memory_pointer;
              end else begin
                track_2_addr <= memory_pointer;
              end
            end

            `INS_SNDL: begin
              if (~mem_dout[16]) begin
                track_1_length <= memory_pointer;
              end else begin
                track_2_length <= memory_pointer;
              end
            end

            `INS_SNDR: begin
              if (~mem_dout[16]) begin
                track_1_loop <= mem_dout[17];
              end else begin
                track_2_loop <= mem_dout[17];
              end
            end

            `INS_SNDW: begin
              if (~mem_dout[16]) begin
                track_1_wr <= 1'b1;
              end else begin
                track_2_wr <= 1'b1;
              end
            end

            `INS_SNDP: begin
              if (~mem_dout[16]) begin
                if (mem_dout[17]) begin
                  track_1_start <= 1'b1;
                end else begin
                  track_1_stop <= 1'b1;
                end
              end else begin
                if (mem_dout[17]) begin
                  track_2_start <= 1'b1;
                end else begin
                  track_1_stop <= 1'b1;
                end
              end
            end

            `INS_IMGD: begin
              next_fetch_two;

              image_width <= mem_dout[17:9];
              image_height <= mem_dout[8:0];
            end

            `INS_IMGCD: begin
              next_fetch_two;

              image_x <= mem_dout[19:10];
              image_y <= mem_dout[9:0];
            end

            `INS_IMGC: begin
              image_x <= registers[`REG_X] > 16'h1FF && registers[`REG_X] <= 16'h7FFF ? {1'b0, 9'd511} :
                registers[`REG_X] < 16'hFE01 && registers[`REG_X] >= 16'h8000 ? {1'b1, 9'd511} :
                {
                  registers[`REG_X][15],
                  registers[`REG_X][15] ? ~registers[`REG_X][8:0] + 9'd1 : registers[`REG_X][8:0]
                };

              image_y <= registers[`REG_Y] > 16'h1FF && registers[`REG_Y] <= 16'h7FFF ? {1'b0, 9'd511} :
                registers[`REG_Y] < 16'hFE01 && registers[`REG_Y] >= 16'h8000 ? {1'b1, 9'd511} :
                {
                  registers[`REG_Y][15],
                  registers[`REG_Y][15] ? ~registers[`REG_Y][8:0] + 9'd1 : registers[`REG_Y][8:0]
                };
            end

            `INS_IMGA: begin
              if ((image_x[9] && image_width >= image_x[8:0]) || (~image_x[9] && 9'd319 >= image_x[8:0])) begin
                if (image_x[9]) begin
                  mem_burst <= (image_width - image_x[8:0]) > 9'd319 ? 9'd319 : (image_width - image_x[8:0]);
                end else begin
                  mem_burst <= (image_x + image_width) > 9'd319 ? 9'd319 - image_x[8:0] : image_width;
                end

                program_counter <= program_counter;
                mem_addr <= mem_addr;
                mem_cs <= 1'b0;

                image_line <= image_y[9] ? image_y[8:0] : 9'd0;
                image_line_dst <= ~image_y[9] ? image_y[8:0] : 9'd0;
                state <= `STATE_READ_LINE;
              end
            end

            `INS_FLIP: begin
              framebuffer <= ~framebuffer;
            end
          endcase
        end
      end

      `STATE_READ_LINE: begin
        if (image_line > image_height || image_line_dst > 9'd239) begin
          next_fetch;
        end else begin
          mem_wr <= 1'b0;
          mem_cs <= 1'b1;
          mem_acc <= `ACC_BURST;
          mem_addr <= memory_pointer + (image_line * (image_width + 9'd1)) + image_start_x_src;
          state <= `STATE_READING;
          glitch <= 16'd0;
        end
      end

      `STATE_WRITE_LINE: begin
        mem_wr <= 1'b1;
        mem_cs <= 1'b1;
        mem_acc <= `ACC_BURST;
        mem_addr <= framebuffer_addr + (image_line_dst * 32'd320) + image_start_x;
        mem_lsb_mask_en <= 1'b1;
        image_line <= image_line + 9'd1;
        image_line_dst <= image_line_dst + 9'd1;
        state <= `STATE_WRITING;
      end

      `STATE_READING: begin
        if (mem_ack) begin
          next_fetch;

          case (working_opcode)
            `INS_LD: begin
              registers[working_reg_a] <= value;
            end

            `INS_LEA: begin
              registers[`REG_MH] <= mem_dout[31:16];
              registers[`REG_ML] <= mem_dout[15:0];
            end

            `INS_POP: begin
              registers[working_reg_a] <= value;
            end

            `INS_RET: begin
              program_counter <= mem_dout;
              mem_addr <= mem_dout;
            end

            `INS_HRD: begin
              next_fetch_two;
            end

            `INS_IMGA: begin
              program_counter <= program_counter;
              mem_addr <= mem_addr;
              mem_cs <= 1'b0;
              state <= `STATE_WRITE_LINE;
            end
          endcase
        end
      end

      `STATE_WRITING: begin
         if (mem_ack) begin
          next_fetch;

          case (working_opcode)
            `INS_ST: begin
            end

            `INS_PUSH: begin
            end

            `INS_CALL: begin
              next_fetch_set_pc;
            end

            `INS_HWR: begin
              next_fetch_two;
            end

            `INS_IMGA: begin
              program_counter <= program_counter;
              mem_addr <= mem_addr;
              mem_cs <= 1'b0;
              state <= `STATE_READ_LINE;
            end
          endcase
        end
      end

      `STATE_ARITHMETIC: begin
        next_fetch;

        case (working_opcode)
          `INS_ADD, `INS_SUB: begin
            {flag_carry, registers[reg_a]} <= temp;
          end

          `INS_CMP: begin
            flag_carry <= temp[16];
          end
        endcase

        flag_zero <= temp == 17'd0;
        flag_sign <= temp[15];
        flag_overflow <= (reg_va[15] & reg_vb[15] & ~temp[15]) |
          (~reg_va[15] & ~reg_vb[15] & temp[15]);
      end

      `STATE_ARITHMETIC_FIXED: begin
        next_fetch;

        flag_zero <= reg_va == 16'd0;
        flag_sign <= reg_va[15];
      end
    endcase
  end
end

endmodule

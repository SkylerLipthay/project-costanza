`include "memory_access.vh"

module memory_map(
  clk,
  
  res,
  addr,
  cs,
  wr,
  acc,
  burst,
  din,
  dout,
  ack,

  ext_high_ram_addr,
  ext_high_ram_din,
  ext_high_ram_wr,
  ext_high_ram_dout,

  ext_sdram_addr,
  ext_sdram_ba,
  ext_sdram_cas_n,
  ext_sdram_cke,
  ext_sdram_cs_n,
  ext_sdram_dq,
  ext_sdram_dqm,
  ext_sdram_ras_n,
  ext_sdram_we_n,

  lsb_mask_en,

  cpu_acc
);

input clk;

input res;
input [31:0] addr;
input cs;
input wr;
input [1:0] acc;
input [8:0] burst;
input [31:0] din;
output reg [31:0] dout;
output reg ack;

input [8:0] ext_high_ram_addr;
input [15:0] ext_high_ram_din;
input ext_high_ram_wr;
output [15:0] ext_high_ram_dout;

input lsb_mask_en;

input cpu_acc;

output [12:0] ext_sdram_addr;
output [1:0] ext_sdram_ba;
output ext_sdram_cas_n;
output ext_sdram_cke;
output ext_sdram_cs_n;
inout [15:0] ext_sdram_dq;
output [1:0] ext_sdram_dqm;
output ext_sdram_ras_n;
output ext_sdram_we_n;

`define MM_STATE_IDLE 2'b00
`define MM_STATE_READ 2'b01
`define MM_STATE_WRITE 2'b10
`define MM_STATE_PAUSE 2'b11

reg [1:0] state;
reg [8:0] word_count;
reg [15:0] ram_din;
reg [1:0] wr_delay;
reg setup;

reg [8:0] int_high_ram_addr;
reg [15:0] int_high_ram_din;
reg int_high_ram_wr;
wire [15:0] int_high_ram_dout;

block_ram high_ram(
  .address_a(int_high_ram_addr),
  .address_b(ext_high_ram_addr),
  .clock(clk),
  .data_a(int_high_ram_din),
  .data_b(ext_high_ram_din),
  .wren_a(int_high_ram_wr),
  .wren_b(ext_high_ram_wr),
  .q_a(int_high_ram_dout),
  .q_b(ext_high_ram_dout)
);

reg [8:0] cpu_ram_addr;
reg [15:0] cpu_ram_din;
reg cpu_ram_wr;
wire [15:0] cpu_ram_dout;

cpu_ram cpu_ram(
  .address(cpu_ram_addr),
  .clock(clk),
  .data(cpu_ram_din),
  .wren(cpu_ram_wr),
  .q(cpu_ram_dout)
);

reg [23:0] sdram_addr_in;
reg [15:0] sdram_data_in;
reg [8:0] sdram_burst;
wire [15:0] sdram_data_out;
reg sdram_req;
reg sdram_wr;
wire sdram_ack;
reg sdram_wr_mask;

sdram_controller sdram_controller(
  .clk(clk),
  .res(res),

  .addr(ext_sdram_addr),
  .ba(ext_sdram_ba),
  .cas_n(ext_sdram_cas_n),
  .cke(ext_sdram_cke),
  .cs_n(ext_sdram_cs_n),
  .dq(ext_sdram_dq),
  .dqm(ext_sdram_dqm),
  .ras_n(ext_sdram_ras_n),
  .we_n(ext_sdram_we_n),

  .addr_in(sdram_addr_in),
  .data_in(sdram_data_in),
  .burst(sdram_burst),
  .data_out(sdram_data_out),
  .req(sdram_req),
  .wr(sdram_wr),
  .ack(sdram_ack),
  .wr_mask(sdram_wr_mask)
);

reg cpu_saved_acc;

always @(posedge clk) begin
  ack <= 1'b0;
  int_high_ram_wr <= 1'b0;
  cpu_ram_wr <= 1'b0;

  if (res) begin
    state <= `MM_STATE_IDLE;
    sdram_data_in = 16'h0000;
    sdram_req <= 1'b0;
    sdram_wr_mask <= 1'b0;
    cpu_saved_acc <= 1'b0;
  end else begin
    case (state)
      `MM_STATE_IDLE: begin
        if (cs) begin
          state <= wr ? `MM_STATE_WRITE : `MM_STATE_READ;
          setup <= 1'b0;
          cpu_saved_acc <= cpu_acc;
        end
      end

      `MM_STATE_READ: begin
        if (~setup) begin
          case (acc)
            `ACC_BURST: sdram_burst <= burst;
            `ACC_WORD: sdram_burst <= 9'd0;
            `ACC_DWORD: sdram_burst <= 9'd1;
          endcase

          sdram_addr_in <= addr[23:0];
          sdram_wr <= 1'b0;
          sdram_req <= 1'b1;
          word_count <= 9'd0;
          setup <= 1'b1;
        end else if (sdram_ack) begin
          sdram_req <= 1'b0;
          word_count <= word_count + 9'd1;

          if (acc != `ACC_BURST) begin
            dout = {dout[15:0], sdram_data_out};
          end else begin
            if (cpu_saved_acc) begin
              cpu_ram_wr <= 1'b1;
              cpu_ram_din <= sdram_data_out;
              cpu_ram_addr <= word_count;
            end else begin
              int_high_ram_wr <= 1'b1;
              int_high_ram_din <= sdram_data_out;
              int_high_ram_addr <= word_count;
            end
          end

          if (word_count == sdram_burst) begin
            state <= `MM_STATE_PAUSE;
            word_count <= 9'd0;
          end
        end
      end

      `MM_STATE_WRITE: begin
        wr_delay <= {1'b0, wr_delay[1]};

        if (~setup) begin
          case (acc)
            `ACC_BURST: sdram_burst <= burst;
            `ACC_WORD: sdram_burst <= 9'd0;
            `ACC_DWORD: sdram_burst <= 9'd1;
          endcase

          sdram_addr_in <= addr[23:0];
          sdram_wr <= 1'b1;
          sdram_req <= 1'b1;
          word_count <= 9'd0;
          wr_delay <= 2'd0;
          if (cpu_saved_acc) begin
            cpu_ram_addr <= 9'd0;
          end else begin
            int_high_ram_addr <= 9'd0;
          end
          setup <= 1'b1;
        end else begin
          if (sdram_ack) begin
            sdram_req <= 1'b0;
            wr_delay[1] <= 1'b1;
            if (cpu_saved_acc) begin
              cpu_ram_addr <= cpu_ram_addr + 9'd1;
            end else begin
              int_high_ram_addr <= int_high_ram_addr + 9'd1;
            end
          end

          if (wr_delay[0]) begin
            word_count <= word_count + 9'd1;

            case (acc)
              `ACC_BURST: begin
                if (cpu_saved_acc) begin
                  sdram_data_in <= cpu_ram_dout;
                  sdram_wr_mask <= lsb_mask_en & ~cpu_ram_dout[0];
                end else begin
                  sdram_data_in <= int_high_ram_dout;
                  sdram_wr_mask <= lsb_mask_en & ~int_high_ram_dout[0];
                end
              end

              `ACC_WORD: begin
                sdram_data_in <= din[15:0];
                sdram_wr_mask <= lsb_mask_en & din[0];
              end

              `ACC_DWORD: begin
                sdram_data_in <= word_count[0] ? din[15:0] : din[31:16];
                sdram_wr_mask <= lsb_mask_en & (word_count[0] ? ~din[0] : ~din[16]);
              end
            endcase

            if (word_count == sdram_burst) begin
              state <= `MM_STATE_PAUSE;
              word_count <= 9'd0;
            end 
          end
        end
      end

      // wait for the sdram to go back to idle before sending more commands
      `MM_STATE_PAUSE: begin
        word_count <= word_count + 9'd1;
        if (word_count == 9'd2) begin
          state <= `MM_STATE_IDLE;
          ack <= 1'b1;
          cpu_saved_acc <= 1'b0;
        end
      end
    endcase
  end
end

endmodule

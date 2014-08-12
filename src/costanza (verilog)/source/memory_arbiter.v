`include "memory_access.vh"

module memory_arbiter(
  clk,
  res,

  sd_cs_n,
  sd_miso,
  sd_mosi,
  sd_clk_out,
  
  cpu_addr,
  cpu_cs,
  cpu_wr,
  cpu_acc,
  cpu_burst,
  cpu_din,
  cpu_dout,
  cpu_ack,
  cpu_lsb_mask_en,

  vga_addr,
  vga_cs,
  vga_acc,
  vga_burst,
  vga_dout,
  vga_ack,

  audio_addr,
  audio_cs,
  audio_dout,
  audio_ack,

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

  sd_finished
);

input clk;
input res;

output sd_cs_n;
input sd_miso;
output sd_mosi;
output sd_clk_out;

input [31:0] cpu_addr;
input cpu_cs;
input cpu_wr;
input [1:0] cpu_acc;
input [8:0] cpu_burst;
input [31:0] cpu_din;
output reg [31:0] cpu_dout;
output reg cpu_ack;
input cpu_lsb_mask_en;

input [31:0] vga_addr;
input vga_cs;
input [1:0] vga_acc;
input [8:0] vga_burst;
output reg [31:0] vga_dout;
output reg vga_ack;

input [31:0] audio_addr;
input audio_cs;
output reg [31:0] audio_dout;
output reg audio_ack;

input [8:0] ext_high_ram_addr;
input [15:0] ext_high_ram_din;
input ext_high_ram_wr;
output [15:0] ext_high_ram_dout;

output [12:0] ext_sdram_addr;
output [1:0] ext_sdram_ba;
output ext_sdram_cas_n;
output ext_sdram_cke;
output ext_sdram_cs_n;
inout [15:0] ext_sdram_dq;
output [1:0] ext_sdram_dqm;
output ext_sdram_ras_n;
output ext_sdram_we_n;

output reg sd_finished;

reg [31:0] mem_addr;
reg mem_cs;
reg mem_wr;
reg [1:0] mem_acc;
reg [8:0] mem_burst;
reg [31:0] mem_din;
wire [31:0] mem_dout;
wire mem_ack;
reg mem_lsb_mask_en;

wire [8:0] mem_high_addr;
wire [15:0] mem_high_din;
wire mem_high_wr;
reg mem_cpu_en;

memory_map memory_map(
  .clk(clk),
  
  .res(res),
  .addr(mem_addr),
  .cs(mem_cs),
  .wr(mem_wr),
  .acc(mem_acc),
  .burst(mem_burst),
  .din(mem_din),
  .dout(mem_dout),
  .ack(mem_ack),

  .ext_high_ram_addr(mem_high_addr),
  .ext_high_ram_din(mem_high_din),
  .ext_high_ram_wr(mem_high_wr),
  .ext_high_ram_dout(ext_high_ram_dout),

  .ext_sdram_addr(ext_sdram_addr),
  .ext_sdram_ba(ext_sdram_ba),
  .ext_sdram_cas_n(ext_sdram_cas_n),
  .ext_sdram_cke(ext_sdram_cke),
  .ext_sdram_cs_n(ext_sdram_cs_n),
  .ext_sdram_dq(ext_sdram_dq),
  .ext_sdram_dqm(ext_sdram_dqm),
  .ext_sdram_ras_n(ext_sdram_ras_n),
  .ext_sdram_we_n(ext_sdram_we_n),

  .lsb_mask_en(mem_lsb_mask_en),

  .cpu_acc(mem_cpu_en)
);

wire sd_ready;
reg [31:0] sd_block_addr;
reg sd_req;
wire sd_ack;
wire [8:0] sd_mem_high_addr;
wire [15:0] sd_mem_high_din;
wire sd_mem_high_wr;

assign mem_high_addr = sd_finished ? ext_high_ram_addr : sd_mem_high_addr;
assign mem_high_din = sd_finished ? ext_high_ram_din : sd_mem_high_din;
assign mem_high_wr = sd_finished ? ext_high_ram_wr : sd_mem_high_wr;

sd_controller sd_controller(
  .clk_bus(clk),

  .res(res),
  .ready(sd_ready),

  .cs_n(sd_cs_n),
  .miso(sd_miso),
  .mosi(sd_mosi),
  .clk_out(sd_clk_out),

  .block_addr(sd_block_addr),
  .req(sd_req),
  .ack(sd_ack),

  .ram_addr(sd_mem_high_addr),
  .ram_dout(sd_mem_high_din),
  .ram_wr(sd_mem_high_wr)
);

`define MA_STATE_SD_INIT 4'd0
`define MA_STATE_SD_READ 4'd1
`define MA_STATE_SD_COPY 4'd2
`define MA_STATE_SD_FINISH 4'd3
`define MA_STATE_IDLE 4'd4
`define MA_STATE_CPU_READ 4'd5
`define MA_STATE_CPU_WRITE 4'd6
`define MA_STATE_VID_READ 4'd7
`define MA_STATE_AUDIO_READ 4'd8

reg [3:0] state;
reg cpu_req;
reg vga_req;
reg audio_req;

always @(posedge clk) begin
  mem_cs <= 1'b0;
  sd_req <= 1'b0;
  cpu_ack <= 1'b0;
  vga_ack <= 1'b0;
  audio_ack <= 1'b0;
  mem_cpu_en <= 1'b0;
  
  if (cpu_cs) begin
    cpu_req <= 1'b1;
  end
  
  if (vga_cs) begin
    vga_req <= 1'b1;
  end

  if (audio_cs) begin
    audio_req <= 1'b1;
  end

  if (res) begin
    mem_lsb_mask_en <= 1'b0;
    state <= `MA_STATE_SD_INIT;
    sd_finished <= 1'b0;
    cpu_req <= 1'b0;
    vga_req <= 1'b0;
    audio_req <= 1'b0;
  end else begin
    case (state)
      `MA_STATE_SD_INIT: begin
        if (sd_ready) begin
          state <= `MA_STATE_SD_READ;
          sd_block_addr <= 32'd0;
        end
      end

      `MA_STATE_SD_READ: begin
        sd_req <= 1'b1;
        state <= `MA_STATE_SD_COPY;
      end

      `MA_STATE_SD_COPY: begin
        if (sd_ack) begin
          mem_addr <= {1'b0, sd_block_addr[31:1]};
          sd_block_addr[31:9] <= sd_block_addr[31:9] + 23'd1;
          mem_cs <= 1'b1;
          mem_wr <= 1'b1;
          mem_acc <= `ACC_BURST;
          mem_burst <= 9'd255;
          state <= `MA_STATE_SD_FINISH;
        end
      end

      `MA_STATE_SD_FINISH: begin
        if (mem_ack) begin
          // 4 megabytes
          if (sd_block_addr[31:9] < 23'h1FFF) begin
            state <= `MA_STATE_SD_READ;
          end else begin
            state <= `MA_STATE_IDLE;
            sd_finished <= 1'b1;
          end
        end
      end

      `MA_STATE_IDLE: begin
        if (vga_cs || vga_req) begin
          vga_req <= 1'b0;
          mem_addr <= vga_addr;
          state <= `MA_STATE_VID_READ;
          mem_burst <= vga_burst;
          mem_acc <= vga_acc;
          mem_cs <= 1'b1;
          mem_wr <= 1'b0;
        end else if (audio_cs || audio_req) begin
          audio_req <= 1'b0;
          mem_addr <= audio_addr;
          state <= `MA_STATE_AUDIO_READ;
          mem_burst <= 1'd0;
          mem_acc <= `ACC_WORD;
          mem_cs <= 1'b1;
          mem_wr <= 1'b0;
        end else if (cpu_cs || cpu_req) begin
          cpu_req <= 1'b0;
          mem_addr <= cpu_addr;
          mem_burst <= cpu_burst;
          mem_acc <= cpu_acc;
          mem_cpu_en <= 1'b1;
          if (cpu_wr) begin
            state <= `MA_STATE_CPU_WRITE;
            mem_din <= cpu_din;
            mem_cs <= 1'b1;
            mem_wr <= 1'b1;
            mem_lsb_mask_en <= cpu_lsb_mask_en;
          end else begin
            state <= `MA_STATE_CPU_READ;
            mem_cs <= 1'b1;
            mem_wr <= 1'b0;
          end
        end
      end

      `MA_STATE_VID_READ: begin
        if (mem_ack) begin
          vga_ack <= 1'b1;
          state <= `MA_STATE_IDLE;
          if (mem_acc != `ACC_BURST) begin
            vga_dout <= mem_dout;
          end
        end
      end
      
      `MA_STATE_CPU_READ: begin
        if (mem_ack) begin
          cpu_ack <= 1'b1;
          mem_lsb_mask_en <= 1'b0;
          state <= `MA_STATE_IDLE;
          if (mem_acc != `ACC_BURST) begin
            cpu_dout <= mem_dout;
          end
        end
      end
      
      `MA_STATE_CPU_WRITE: begin
        if (mem_ack) begin
          cpu_ack <= 1'b1;
          state <= `MA_STATE_IDLE;
        end
      end

      `MA_STATE_AUDIO_READ: begin
        if (mem_ack) begin
          audio_ack <= 1'b1;
          state <= `MA_STATE_IDLE;
          audio_dout <= mem_dout;
        end
      end
    endcase
  end
end

endmodule

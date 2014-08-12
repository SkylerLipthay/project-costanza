`include "source/memory_access.vh"

module costanza(
	CLOCK_50,
	LED,
	KEY,
	SW,
	DRAM_ADDR,
	DRAM_BA,
	DRAM_CAS_N,
	DRAM_CKE,
	DRAM_CLK,
	DRAM_CS_N,
	DRAM_DQ,
	DRAM_DQM,
	DRAM_RAS_N,
	DRAM_WE_N,
	IO_A,
	IO_A_IN,
	IO_B,
	IO_B_IN
);

input CLOCK_50;
output [7:0] LED;
input [1:0] KEY;
input [3:0] SW;
output [12:0] DRAM_ADDR;
output [1:0] DRAM_BA;
output DRAM_CAS_N;
output DRAM_CKE;
output DRAM_CLK;
output DRAM_CS_N;
inout [15:0] DRAM_DQ;
output [1:0] DRAM_DQM;
output DRAM_RAS_N;
output DRAM_WE_N;
inout [33:0] IO_A;
input [1:0] IO_A_IN;
inout [33:0] IO_B;
input [1:0] IO_B_IN;

wire joypad_clock;
wire sdram_clock;
wire vga_clock;

pll_main pll_main(
	.inclk0(CLOCK_50),
	.c0(joypad_clock),
	.c1(sdram_clock),
	.c2(DRAM_CLK)
);

reg res;

wire [4:0] vga_red;
wire [4:0] vga_green;
wire [4:0] vga_blue;
wire [31:0] vga_mem_addr;
wire vga_mem_cs;
wire [1:0] vga_mem_acc;
wire [8:0] vga_mem_burst;
wire [31:0] vga_mem_dout;
wire vga_mem_ack;
wire [8:0] vga_high_ram_addr;
wire [15:0] vga_high_ram_din;
wire vga_high_ram_wr;
wire [15:0] vga_high_ram_dout;
wire vga_framebuffer;
wire vga_vblank;
assign IO_A[23:19] = vga_red;
assign IO_A[28:24] = vga_green;
assign IO_A[33:29] = vga_blue;

vga_controller vga_controller(
  .clk(sdram_clock),
  .res(res),

  .hsync(IO_A[17]),
  .vsync(IO_A[18]),
  .red(vga_red),
  .green(vga_green),
  .blue(vga_blue),

  .framebuffer(vga_framebuffer),
  .vblank(vga_vblank),

  .mem_addr(vga_mem_addr),
  .mem_cs(vga_mem_cs),
  .mem_acc(vga_mem_acc),
  .mem_burst(vga_mem_burst),
  .mem_dout(vga_mem_dout),
  .mem_ack(vga_mem_ack),

  .high_ram_addr(vga_high_ram_addr),
  .high_ram_din(vga_high_ram_din),
  .high_ram_wr(vga_high_ram_wr),
  .high_ram_dout(vga_high_ram_dout)
);

wire [31:0] audio_mem_addr;
wire audio_mem_cs;
wire [31:0] audio_mem_dout;
wire audio_mem_ack;
wire [31:0] cpu_track_1_addr;
wire [31:0] cpu_track_1_length;
wire cpu_track_1_loop;
wire cpu_track_1_wr;
wire cpu_track_1_start;
wire cpu_track_1_stop;
wire [31:0] cpu_track_2_addr;
wire [31:0] cpu_track_2_length;
wire cpu_track_2_loop;
wire cpu_track_2_wr;
wire cpu_track_2_start;
wire cpu_track_2_stop;

audio_controller audio_controller(
  .clk(sdram_clock),
  .res(res),

  .pwm(IO_A[6]),

  .mem_addr(audio_mem_addr),
  .mem_cs(audio_mem_cs),
  .mem_dout(audio_mem_dout),
  .mem_ack(audio_mem_ack),

  .track_1_addr(cpu_track_1_addr),
  .track_1_length(cpu_track_1_length),
  .track_1_loop(cpu_track_1_loop),
  .track_1_wr(cpu_track_1_wr),
  .track_1_start(cpu_track_1_start),
  .track_1_stop(cpu_track_1_stop),

  .track_2_addr(cpu_track_2_addr),
  .track_2_length(cpu_track_2_length),
  .track_2_loop(cpu_track_2_loop),
  .track_2_wr(cpu_track_2_wr),
  .track_2_start(cpu_track_2_start),
  .track_2_stop(cpu_track_2_stop)
);

wire [11:0] joypad_1;
wire [11:0] joypad_2;

joypad_controller joypad_controller(
  .clk(joypad_clock),
  .res(res),

  .latch(IO_A[9]),
  .data_1(IO_A[11]),
  .data_2(IO_A[12]),
  .clkout_1(IO_A[10]),
  .clkout_2(IO_A[8]),
  .button_data_1(joypad_1),
  .button_data_2(joypad_2)
);

wire [31:0] cpu_mem_addr;
wire cpu_mem_cs;
wire cpu_mem_wr;
wire [1:0] cpu_mem_acc;
wire [8:0] cpu_mem_burst;
wire [31:0] cpu_mem_din;
wire [31:0] cpu_mem_dout;
wire cpu_mem_ack;
wire cpu_mem_lsb_mask_en;

cpu cpu(
  .clk(sdram_clock),
  .res(res),

  .mem_addr(cpu_mem_addr),
  .mem_cs(cpu_mem_cs),
  .mem_wr(cpu_mem_wr),
  .mem_acc(cpu_mem_acc),
  .mem_burst(cpu_mem_burst),
  .mem_din(cpu_mem_din),
  .mem_dout(cpu_mem_dout),
  .mem_ack(cpu_mem_ack),
  .mem_lsb_mask_en(cpu_mem_lsb_mask_en),

  .joypad_1(joypad_1),
  .joypad_2(joypad_2),

  .framebuffer(vga_framebuffer),
  .vblank(vga_vblank),

  .track_1_addr(cpu_track_1_addr),
  .track_1_length(cpu_track_1_length),
  .track_1_loop(cpu_track_1_loop),
  .track_1_wr(cpu_track_1_wr),
  .track_1_start(cpu_track_1_start),
  .track_1_stop(cpu_track_1_stop),

  .track_2_addr(cpu_track_2_addr),
  .track_2_length(cpu_track_2_length),
  .track_2_loop(cpu_track_2_loop),
  .track_2_wr(cpu_track_2_wr),
  .track_2_start(cpu_track_2_start),
  .track_2_stop(cpu_track_2_stop)
);

wire sd_finished;

memory_arbiter memory_arbiter(
  .clk(sdram_clock),
  .res(res),

  .sd_cs_n(IO_A[1]),
  .sd_miso(IO_A[4]),
  .sd_mosi(IO_A[2]),
  .sd_clk_out(IO_A[3]),
  
  .cpu_addr(cpu_mem_addr),
  .cpu_cs(cpu_mem_cs),
  .cpu_wr(cpu_mem_wr),
  .cpu_acc(cpu_mem_acc),
  .cpu_burst(cpu_mem_burst),
  .cpu_din(cpu_mem_din),
  .cpu_dout(cpu_mem_dout),
  .cpu_ack(cpu_mem_ack),
  .cpu_lsb_mask_en(cpu_mem_lsb_mask_en),

  .vga_addr(vga_mem_addr),
  .vga_cs(vga_mem_cs),
  .vga_acc(vga_mem_acc),
  .vga_burst(vga_mem_burst),
  .vga_dout(vga_mem_dout),
  .vga_ack(vga_mem_ack),

  .audio_addr(audio_mem_addr),
  .audio_cs(audio_mem_cs),
  .audio_dout(audio_mem_dout),
  .audio_ack(audio_mem_ack),

  .ext_high_ram_addr(vga_high_ram_addr),
  .ext_high_ram_din(vga_high_ram_din),
  .ext_high_ram_wr(vga_high_ram_wr),
  .ext_high_ram_dout(vga_high_ram_dout),

  .ext_sdram_addr(DRAM_ADDR),
  .ext_sdram_ba(DRAM_BA),
  .ext_sdram_cas_n(DRAM_CAS_N),
  .ext_sdram_cke(DRAM_CKE),
  .ext_sdram_cs_n(DRAM_CS_N),
  .ext_sdram_dq(DRAM_DQ),
  .ext_sdram_dqm(DRAM_DQM),
  .ext_sdram_ras_n(DRAM_RAS_N),
  .ext_sdram_we_n(DRAM_WE_N),

  .sd_finished(sd_finished)
);

initial begin
	res = 1'b1;
end

always @(posedge sdram_clock) begin
  res <= 1'b0;

  if (~KEY[0]) begin
    res <= 1'b1;
  end
end

endmodule

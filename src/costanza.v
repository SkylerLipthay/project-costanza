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

reg res;

wire joypad_clock;
wire sdram_clock;
wire sdram_clock_advanced;
wire vga_clock;

wire [4:0] vga_red;
wire [4:0] vga_green;
wire [4:0] vga_blue;

assign IO_A[23:19] = vga_red;
assign IO_A[28:24] = vga_green;
assign IO_A[33:29] = vga_blue;

pll_main pll_main(
	.inclk0(CLOCK_50),
	.c0(joypad_clock),
	.c1(sdram_clock),
	.c2(sdram_clock_advanced),
  .c3(vga_clock)
);

vga_controller vga_controller(
  .clk(vga_clock),
  .hsync(IO_A[17]),
  .vsync(IO_A[18]),
  .red(vga_red),
  .green(vga_green),
  .blue(vga_blue)
);

assign DRAM_CLK = sdram_clock_advanced;

wire [11:0] joypad_one_data;
wire joypad_data;
wire joypad_latch;
wire joypad_clkout;

assign joypad_data = 1'b0;
assign joypad_latch = 1'b0;
assign joypad_clkout = 1'b0;

joypad_controller joypad_one(
	.clk(joypad_clock),
  .res(res),
  .data(joypad_data),
  .latch(joypad_latch),
  .clkout(joypad_clkout),
  .button_data(joypad_one_data)
);

reg [23:0] sdram_addr_in;
reg [15:0] sdram_data_in;
reg [8:0] sdram_burst;
wire [15:0] sdram_data_out;
reg sdram_req;
reg sdram_wr;
wire sdram_ack;

sdram_controller sdram_controller(
	.clk(sdram_clock),
	.res(res),
	.addr(DRAM_ADDR),
	.ba(DRAM_BA),
	.cas_n(DRAM_CAS_N),
	.cke(DRAM_CKE),
	.cs_n(DRAM_CS_N),
	.dq(DRAM_DQ),
	.dqm(DRAM_DQM),
	.ras_n(DRAM_RAS_N),
	.we_n(DRAM_WE_N),

	.addr_in(sdram_addr_in),
  .data_in(sdram_data_in),
  .burst(sdram_burst),
  .data_out(sdram_data_out),
  .req(sdram_req),
  .wr(sdram_wr),
  .ack(sdram_ack)
);

reg [21:0] count;
reg [7:0] LED;
wire sd_ready;

initial begin
	res = 1'b1;
  sdram_data_in = 16'h0000;
  sdram_req <= 1'b0;
  LED <= 8'd0;
end

always @(posedge sdram_clock) begin
  LED[0] <= sd_ready;

  if (~KEY[0]) begin
    res <= 1'b0;
  end

  /*count <= count + 1'd1;

	if (res == 1'b1) begin
    count <= 22'd0;
    sdram_req <= 1'b0;
  end

	if (count == 22'd2266140) begin
		sdram_addr_in <= 24'h000100;
		sdram_burst <= 9'd8;
		sdram_req <= 1'b1;
		sdram_wr <= 1'b0;
	end

	if (sdram_ack) begin
    sdram_req <= 1'b0;
		LED <= sdram_data_out[7:0];
	end

  if (count == 22'd2262140) begin
    sdram_addr_in <= 24'h000200;
    sdram_burst <= 9'h1FF;
    sdram_req <= 1'b1;
    sdram_wr <= 1'b1;
  end

  if (sdram_ack) begin
    sdram_req <= 1'b0;
    sdram_data_in <= 16'h5678;
  end*/
end

wire low_sd_clock;

pll_sd pll_sd(
  .inclk0(CLOCK_50),
  .c0(low_sd_clock)
);

sd_controller sd_controller(
  .clk_bus(sdram_clock),
  .clk_fast(vga_clock),
  .clk_slow(low_sd_clock),

  .res(res),
  .ready(sd_ready),

  .cs(IO_A[1]),
  .miso(IO_A[4]),
  .mosi(IO_A[2]),
  .clk_out(IO_A[3])
);

/*reg pwm;
reg [11:0] sample;
reg [7:0] step;
reg [3:0] pulse;
reg [7:0] audio_data [4095:0];
assign IO_A[6] = pwm;

initial begin
  pwm = 1'b0;
  sample = 8'd0;
  step = 8'd0;
  pulse = 4'd0;
  $readmemh("./hex/output.hex", audio_data);
end

always @(posedge sdram_clock) begin
  if (step == 8'd255) begin
    pulse <= pulse + 4'd1;
    if (pulse == 4'd8) begin
      // sawtooth
      sample <= sample + 11'd1;
      if (sample == 11'd3710) begin
        sample <= 11'd0;
      end
      pulse <= 4'd0;
    end
  end

  pwm <= step < audio_data[sample] ? 1'b1 : 1'b0;
  step <= step + 8'd1;
end*/

endmodule

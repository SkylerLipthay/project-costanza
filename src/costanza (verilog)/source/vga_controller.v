`include "memory_access.vh"

module vga_controller(
  clk,
  res,

  hsync,
  vsync,
  red,
  green,
  blue,

  framebuffer,
  vblank,

  mem_addr,
  mem_cs,
  mem_acc,
  mem_burst,
  mem_dout,
  mem_ack,

  high_ram_addr,
  high_ram_din,
  high_ram_wr,
  high_ram_dout
);

input clk;
input res;

output reg hsync;
output reg vsync;
output reg [4:0] red;
output reg [4:0] green;
output reg [4:0] blue;

input framebuffer;
output reg vblank;

output reg [31:0] mem_addr;
output reg mem_cs;
output reg [1:0] mem_acc;
output reg [8:0] mem_burst;
input [31:0] mem_dout;
input mem_ack;

output reg [8:0] high_ram_addr;
output [15:0] high_ram_din;
output high_ram_wr;
input [15:0] high_ram_dout;

assign high_ram_din = 16'd0;
assign high_ram_wr = 1'b0;

reg [11:0] h_count;
reg [10:0] v_count;
reg framebuffer_save;

always @(posedge clk) begin
  { hsync, vsync } = 2'b11;
  { red, green, blue } = 15'd0;
  h_count <= h_count + 12'd1;
  mem_cs <= 1'b0;
  vblank <= 1'b0;

  if (res) begin
    h_count <= 12'd0;
    v_count <= 11'd0;
    framebuffer_save <= framebuffer;
  end else begin
    if (v_count >= 11'd45 && v_count < 11'd525) begin
      if (h_count >= 12'd190 &&  h_count[1:0] == 2'b10) begin
        high_ram_addr <= ((h_count - 12'd190) >> 3) & {9{1'b1}};
        if (v_count == 11'd524 && h_count == 12'd190) begin
          vblank <= 1'b1;
        end
      end

      if (h_count >= 12'd192 && h_count < 12'd2752) begin
        red <= high_ram_dout[15:11];
        green <= high_ram_dout[10:6];
        blue <= high_ram_dout[5:1];
      end
    end

    if (h_count == 12'd3199) begin
      h_count <= 12'd0;
      v_count <= v_count + 11'd1;
      if (v_count == 11'd524) begin
        v_count <= 11'd0;
      end
    end

    if (v_count == 11'd44 && h_count == 12'd2516) begin
      framebuffer_save <= framebuffer;
    end

    if (v_count >= 11'd44 && v_count < 11'd524 && ~v_count[0]) begin
      if (h_count == 12'd2517) begin
        mem_cs <= 1'b1;
        mem_addr = (~framebuffer_save ? 32'hFDA800 : 32'hFED400 ) +
          (((v_count - 11'd44) >> 1) * 9'd320);
        mem_acc <= `ACC_BURST;
        mem_burst <= 9'd320;
      end
    end

    if (h_count >= 12'd2816 && h_count < 12'd3200) begin
      hsync <= 1'b0;
    end

    if (v_count >= 11'd10 && v_count < 11'd12) begin
      vsync <= 1'b0;
    end
  end
end

endmodule

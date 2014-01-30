module vga_controller(
  clk,
  hsync,
  vsync,
  red,
  green,
  blue
);

input clk;
output reg hsync;
output reg vsync;
output reg [4:0] red;
output reg [4:0] green;
output reg [4:0] blue;

reg [9:0] h_count;
reg [9:0] v_count;
reg [10:0] counter;

initial begin
  { hsync, vsync } = 2'b11;
  { red, green, blue, h_count, v_count } = 35'd0;
  counter <= 11'd0;
end

always @(posedge clk) begin
  { red, green, blue } <= 15'd0;
  { hsync, vsync } <= 2'b11;
  h_count <= h_count + 10'd1;

  if (h_count == 6'd47) begin
    counter <= counter + 11'd1;
  end

  if (v_count >= 6'd33 && v_count < 10'd513) begin
    if (h_count >= 6'd48 && h_count < 10'd688) begin
      green <= 5'd0;
      red <= 5'd0;
      blue <= 5'd0;
    end
  end
  
  if (h_count >= 10'd704 && h_count < 10'd800) begin
    hsync <= 1'b0;
    if (h_count == 10'd799) begin
      h_count <= 10'd0;
      v_count <= v_count + 10'd1;
      if (v_count == 10'd524) begin
        v_count <= 10'd0;
      end
    end
  end

  if (v_count == 10'd523 || v_count == 10'd524) begin
    vsync <= 1'b0;
    counter <= 11'd0;
  end
end

endmodule

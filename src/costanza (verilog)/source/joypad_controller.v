module joypad_controller(
  clk,
  res,

  latch,
  data_1,
  data_2,
  clkout_1,
  clkout_2,
  button_data_1,
  button_data_2
);

input clk;
input res;

output latch;
input data_1;
input data_2;
output clkout_1;
output clkout_2;
output [11:0] button_data_1;
output [11:0] button_data_2;

`define WAIT_STATE 2'd0
`define LATCH_STATE 2'd1
`define READ_STATE 2'd2

reg [1:0] state;
reg [3:0] button_index;
reg [15:0] button_data_enc_1;
reg [15:0] button_data_enc_2;
reg [10:0] count;

always @(posedge clk) begin
  if (res) begin
    state <= `WAIT_STATE;
    count <= 11'd0;
    button_data_enc_1 <= 16'd0;
    button_data_enc_2 <= 16'd0;
  end else begin
    if (state == `WAIT_STATE) begin
      button_index <= 4'd0;
      count <= count + 1'b1;
      if (count >= 11'd1371) begin
        state <= `LATCH_STATE;
      end
    end else if (state == `LATCH_STATE) begin
      state <= `READ_STATE;
    end else if (state == `READ_STATE) begin
      button_data_enc_1[button_index] <= ~data_1;
      button_data_enc_2[button_index] <= ~data_2;

      button_index <= button_index + 1'b1;
      
      if (button_index == 4'd15) begin
        state <= `WAIT_STATE;
        count <= 11'd0;
      end
    end
  end
end

assign latch = (state == `LATCH_STATE) ? 1'b1 : 1'b0;
assign clkout_1 = (state == `READ_STATE) ? clk : 1'b1;
assign clkout_2 = clkout_1;

// From 0 to 11: up, down, left, right, A, B, X, Y, L, R, select, start
assign button_data_1[11:0] = {
  button_data_enc_1[3],
  button_data_enc_1[2],
  button_data_enc_1[11],
  button_data_enc_1[10],
  button_data_enc_1[1],
  button_data_enc_1[9],
  button_data_enc_1[0],
  button_data_enc_1[8],
  button_data_enc_1[7:4]
};

assign button_data_2[11:0] = {
  button_data_enc_2[3],
  button_data_enc_2[2],
  button_data_enc_2[11],
  button_data_enc_2[10],
  button_data_enc_2[1],
  button_data_enc_2[9],
  button_data_enc_2[0],
  button_data_enc_2[8],
  button_data_enc_2[7:4]
};

endmodule

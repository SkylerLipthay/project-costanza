module joypad_controller(
  clk,
  res,
  data,
  latch,
  clkout,
  button_data
);

input clk;
input res;
input data;
output latch;
output clkout;
output [11:0] button_data;

`define WAIT_STATE 2'd0
`define LATCH_STATE 2'd1
`define READ_STATE 2'd2

reg [1:0] state;
reg [3:0] button_index;
reg [15:0] button_data_enc;
reg [10:0] count;

always @(posedge clk) begin
  if (res) begin
    state <= `WAIT_STATE;
    count <= 11'd0;
    button_data_enc <= 16'd0;
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
      button_data_enc[button_index] <= ~data;

      button_index <= button_index + 1'b1;
      
      if (button_index == 4'd15) begin
        state <= `WAIT_STATE;
        count <= 11'd0;
      end
    end
  end
end

assign latch = (state == `LATCH_STATE) ? 1'b1 : 1'b0;
assign clkout = (state == `READ_STATE) ? clk : 1'b1;

// From 0 to 11: up, down, left, right, A, B, X, Y, L, R, select, start
assign button_data[11:0] = {
  button_data_enc[3],
  button_data_enc[2],
  button_data_enc[11],
  button_data_enc[10],
  button_data_enc[1],
  button_data_enc[9],
  button_data_enc[0],
  button_data_enc[8],
  button_data_enc[7:4]
};

endmodule

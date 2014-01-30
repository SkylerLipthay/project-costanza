module sd_controller(
  clk_bus,
  clk_fast,
  clk_slow,

  res,
  ready,

  cs,
  miso,
  mosi,
  clk_out
);

input clk_bus;
input clk_fast;
input clk_slow;
input res;
output reg ready;
output reg cs;
input miso;
output reg mosi;
output clk_out;

reg [3:0] state;
reg [7:0] count;
reg [5:0] cmd_count;
reg send_cmd;
reg [5:0] cmd;
reg [31:0] arg;
reg [6:0] crc;
reg [2:0] resp_count;
reg recv_resp;
reg [6:0] resp;

wire clk_out_slow;

`define STATE_INIT 4'd0
`define STATE_WAIT_ZERO 4'd1
`define STATE_WAIT_IDLE 4'd2
`define STATE_WAIT_IDLE_CLEARED 4'd3
`define STATE_IDLE 4'd4

assign clk_out_slow = (state <= `STATE_WAIT_IDLE_CLEARED ? 1'b1 : 1'b0);
assign clk_out = clk_out_slow ? clk_slow : clk_fast;

always @(posedge clk_slow) begin
  if (res) begin
    state <= `STATE_INIT;
    count <= 8'd0;
    cs <= 1'b0;
    send_cmd <= 1'b0;
    recv_resp <= 1'b0;
    mosi <= 1'b1;
    cmd <= 6'd0;
    arg <= 32'd0;
    crc <= 7'h2F;
    ready <= 1'b0;
  end else if (clk_out_slow) begin
    if (~send_cmd && ~recv_resp) begin
      count <= count + 8'd1;

      case (state)
        `STATE_INIT: begin
          if (count == 8'd73) begin
            cs <= 1'b1;
          end else if (count == 8'd89) begin
            cmd_count <= 6'd0;
            send_cmd <= 1'b1;
            cmd <= 6'd0;
          end
        end

        `STATE_WAIT_ZERO, `STATE_WAIT_IDLE, `STATE_WAIT_IDLE_CLEARED: begin
          cs <= 1'b1;
          if (miso == 1'b0) begin
            resp_count <= 3'd0;
            recv_resp <= 1'b1;
            resp <= 7'd0;
          end
        end
      endcase
    end else if (recv_resp) begin
      resp_count <= resp_count + 3'd1;

      if (resp_count < 3'd7) begin
        resp[resp_count[2:0]] <= miso;
      end else begin
        recv_resp <= 1'b0;

        case (state)
          `STATE_WAIT_ZERO: begin
            cmd_count <= 6'd0;
            send_cmd <= 1'b1;
            cmd <= 6'd55;
          end

          `STATE_WAIT_IDLE: begin
            cmd_count <= 6'd0;
            send_cmd <= 1'b1;
            cmd <= 6'd41;
          end

          `STATE_WAIT_IDLE_CLEARED: begin
            if (resp == 7'd0) begin
              state <= `STATE_IDLE;
              count <= 8'd0;
              ready <= 1'b1;
            end
          end
        endcase
      end
    end else if (send_cmd) begin
      cmd_count <= cmd_count + 6'd1;

      if (cmd_count[5:0] == 6'd0) begin
        cs <= 1'b0;
        mosi <= 1'b0;
      end else if (cmd_count == 6'd1) begin
        mosi <= 1'b1;
      end else if (cmd_count < 6'd8) begin
        mosi <= cmd[3'd5 - (cmd_count[2:0] - 3'd2)];
      end else if (cmd_count[5:0] < 6'd40) begin
        mosi <= arg[6'd31 - (cmd_count - 6'd8)];
      end else if (cmd_count[5:0] < 6'd47) begin
        mosi <= crc[6'd39 - (cmd_count - 6'd40)];
      end else if (cmd_count == 6'd47) begin
        send_cmd <= 1'b0;
        mosi <= 1'b1;

        case (state)
          `STATE_INIT: begin
            state <= `STATE_WAIT_ZERO;
            count <= 8'd0;
          end

          `STATE_WAIT_ZERO: begin
            state <= `STATE_WAIT_IDLE;
            count <= 8'd0;
          end

          `STATE_WAIT_IDLE: begin
            state <= `STATE_WAIT_IDLE_CLEARED;
            count <= 8'd0;
          end
        endcase
      end
    end
  end
end

always @(clk_fast) begin
  if (~clk_out_slow) begin
    
  end
end

endmodule

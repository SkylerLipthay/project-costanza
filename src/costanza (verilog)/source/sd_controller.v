module sd_controller(
  clk_bus, // 100mhz

  res,
  ready,

  cs_n,
  miso,
  mosi,
  clk_out,

  block_addr,
  req,
  ack,

  ram_addr,
  ram_dout,
  ram_wr
);

input clk_bus;

input res;
output reg ready;

output cs_n;
input miso;
output reg mosi;
output reg clk_out;

input [31:0] block_addr;
input req;
output reg ack;

output reg [8:0] ram_addr;
output reg [15:0] ram_dout;
output reg ram_wr;

reg oe;
reg [3:0] state_next;
reg [3:0] state;
reg [6:0] clk_div;
reg [5:0] cmd_index;
reg [31:0] cmd_arg;
reg [47:0] cmd_send;
reg [6:0] count;
reg [9:0] byte_count;
reg [6:0] clk_cnt;
reg [15:0] resp;

assign cs_n = ~oe;

`define SD_STATE_WAIT_START 4'd0
`define SD_STATE_SELECT 4'd1
`define SD_STATE_RESET 4'd2
`define SD_STATE_RESET_CONF 4'd3
`define SD_STATE_INIT_PREFIX 4'd4
`define SD_STATE_INIT 4'd5
`define SD_STATE_INIT_CONF 4'd6
`define SD_STATE_IDLE 4'd7
`define SD_STATE_READ_BLOCK 4'd8

`define SD_STATE_PREP_SEND 4'd13
`define SD_STATE_SEND 4'd14
`define SD_STATE_RECV 4'd15

always @(posedge clk_bus) begin
  ram_wr <= 1'b0;
  ack <= 1'b0;

  if (res) begin
    clk_out <= 1'b0;
    mosi <= 1'b1;
    oe <= 1'b0;
    state <= `SD_STATE_WAIT_START;
    clk_div <= 7'd0;
    count <= 7'd0;
    cmd_arg <= 32'd0;
    clk_cnt <= 7'd124;
    ready <= 1'b0;
    resp <= 16'd0;
  end else begin
    clk_div <= clk_div + 7'd1;

    case (state)
      `SD_STATE_WAIT_START: begin
        // use this huge-ass thing as a counter
        cmd_arg <= cmd_arg + 32'd1;

        // wait 1.5ms
        if (cmd_arg == 32'd149999) begin
          cmd_arg <= 32'd0;
          state <= `SD_STATE_SELECT;
        end
      end

      `SD_STATE_SELECT: begin
        if (clk_div == clk_cnt) begin
          clk_div <= 7'd0;
          clk_out <= ~clk_out;

          // falling edge
          if (clk_out) begin
            count <= count + 7'd1;

            if (count == 7'd79) begin
              state <= `SD_STATE_RESET;
            end
          end
        end
      end

      `SD_STATE_RESET: begin
        state <= `SD_STATE_PREP_SEND;
        state_next <= `SD_STATE_RESET_CONF;

        cmd_index <= 6'd0;
      end

      `SD_STATE_RESET_CONF: begin
        if (resp[7:0]== 8'b00000001) begin
          state <= `SD_STATE_INIT_PREFIX;
        end
      end

      `SD_STATE_INIT_PREFIX: begin
        state <= `SD_STATE_PREP_SEND;
        state_next <= `SD_STATE_INIT;

        cmd_index <= 6'd55;
      end

      `SD_STATE_INIT: begin
        if (resp[7:0] == 8'b00000001) begin
          state <= `SD_STATE_PREP_SEND;
          state_next <= `SD_STATE_INIT_CONF;

          cmd_index <= 6'd41;
        end
      end

      `SD_STATE_INIT_CONF: begin
        if (resp[7:0] == 8'b00000000) begin
          state <= `SD_STATE_IDLE;
          ready <= 1'b1;
          clk_div <= 7'd0;
          clk_cnt <= 7'd1;
        end else if (resp[7:0] == 8'b00000001) begin
          state <= `SD_STATE_INIT_PREFIX;
        end
      end

      `SD_STATE_IDLE: begin
        if (clk_div == clk_cnt) begin
          clk_div <= 7'd0;
          clk_out <= ~clk_out;
        end

        if (req) begin
          state <= `SD_STATE_PREP_SEND;
          state_next <= `SD_STATE_READ_BLOCK;
          cmd_index <= 6'd17;
          // read block 0
          cmd_arg <= block_addr;
        end
      end

      `SD_STATE_READ_BLOCK: begin
        if (clk_div == clk_cnt) begin
          clk_div <= 7'd0;
          clk_out <= ~clk_out;

          // falling edge
          if (clk_out) begin
            if (miso == 1'b0 && count == 7'd0) begin
              count <= 7'd1;
              byte_count <= 10'd0;
            end

            if (count >= 7'd1) begin
              count <= count + 7'd1;
              resp <= {resp[14:0], miso};

              if (count == 7'd8) begin
                count <= 7'd1;
                byte_count <= byte_count + 10'd1;

                // crazy logic to convert 8-bit to 16-bit
                if (byte_count <= 10'd511 && byte_count[0]) begin
                  ram_addr <= {1'b0, byte_count[8:1]};
                  ram_dout <= {resp[14:0], miso};
                  ram_wr <= 1'b1;
                end
                // 512 bytes + 2 crc bytes + 1 delay byte
                if (byte_count == 10'd514) begin
                  state <= `SD_STATE_IDLE;
                  oe <= 1'b0;
                  ack <= 1'b1;
                end
              end
            end
          end
        end
      end

      `SD_STATE_PREP_SEND: begin
        state <= `SD_STATE_SEND;
        clk_div <= 7'd0;
        count <= 7'd0;

        cmd_send <= {2'b01, cmd_index, cmd_arg, 8'h95};
      end

      `SD_STATE_SEND: begin
        if (clk_div == clk_cnt) begin
          clk_div <= 7'd0;
          clk_out <= ~clk_out;

          // falling edge
          if (clk_out) begin
            oe <= 1'b1;
            count <= count + 7'd1;

            mosi <= cmd_send[47];
            cmd_send <= {cmd_send[46:0], 1'b1};
            if (count == 7'd48) begin
              count <= 7'd0;
              state <= `SD_STATE_RECV;
            end
          end
        end
      end

      `SD_STATE_RECV: begin
        if (clk_div == clk_cnt) begin
          clk_div <= 7'd0;
          clk_out <= ~clk_out;

          // falling edge
          if (clk_out) begin
            if (miso == 1'b0 || count > 7'd0) begin
              count <= count + 7'd1;

              
              if (count <= 7'd7) begin
                resp <= {resp[14:0], miso};
              end

              if (count == 7'd7) begin
                if (state_next != `SD_STATE_READ_BLOCK) begin
                  oe <= 1'b0;
                end
              end

              if (count == 7'd15) begin
                // give the card an extra 8 cycles of breathing room before
                // another possible command
                count <= 7'd0;
                state <= state_next;
              end
            end
          end
        end
      end
    endcase
  end
end

endmodule

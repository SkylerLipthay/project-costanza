module audio_controller(
  clk,
  res,

  pwm,

  mem_addr,
  mem_cs,
  mem_dout,
  mem_ack,

  track_1_addr,
  track_1_length,
  track_1_loop,
  track_1_wr,
  track_1_start,
  track_1_stop,

  track_2_addr,
  track_2_length,
  track_2_loop,
  track_2_wr,
  track_2_start,
  track_2_stop
);

input clk;
input res;

output reg pwm;

output reg [31:0] mem_addr;
output reg mem_cs;
input [31:0] mem_dout;
input mem_ack;

input [31:0] track_1_addr;
input [31:0] track_1_length;
input track_1_loop;
input track_1_wr;
input track_1_start;
input track_1_stop;

input [31:0] track_2_addr;
input [31:0] track_2_length;
input track_2_loop;
input track_2_wr;
input track_2_start;
input track_2_stop;

reg [31:0] base_addr [0:1];
reg [31:0] length [0:1];
reg [31:0] counter [0:1];
reg [31:0] sample [0:1];
reg active [0:1];
reg loop [0:1];
reg [7:0] step;
reg [3:0] pulse;
reg fetch;
reg [2:0] fetch_count;

wire [15:0] high_mult;
wire [15:0] high_mult_plus;
wire [7:0] high_final;
wire [15:0] low_mult;
wire [15:0] low_mult_plus;
wire [7:0] low_final;

assign high_mult = (sample[0][15:8] * sample[1][15:8]) / 8'd128;
assign high_mult_plus = ((sample[0][15:8] + sample[1][15:8]) << 1) - high_mult - 10'd512;
assign high_final = (sample[0][15:8] < 8'd128 && sample[1][15:8] < 8'd128) ? high_mult : high_mult_plus;
assign low_mult = (sample[0][7:0] * sample[1][7:0]) / 8'd128;
assign low_mult_plus = ((sample[0][7:0] + sample[1][7:0]) << 1) - low_mult - 10'd512;
assign low_final = (sample[0][7:0] < 8'd128 && sample[1][7:0] < 8'd128) ? low_mult : low_mult_plus;

always @(posedge clk) begin
  step <= step + 8'd1;
  mem_cs <= 1'b0;

  if (res) begin
    sample[0] <= {4{8'd128}};
    active[0] <= 1'b0;
    sample[1] <= {4{8'd128}};
    active[1] <= 1'b0;
    step <= 8'd0;
    pulse <= 4'd0;
    pwm <= 1'b0;
    mem_addr <= 32'd0;
    fetch <= 1'b1;
    fetch_count <= 3'd0;
  end else begin
    if (track_1_wr) begin
      base_addr[0] <= track_1_addr;
      length[0] <= track_1_length;
      loop[0] <= track_1_loop;
      counter[0] <= 32'd0;
    end

    if (track_1_start) begin
      active[0] <= 1'b1;
    end

    if (track_1_stop) begin
      active[0] <= 1'b0;
      sample[0] <= {4{8'd128}};
    end

    if (track_2_wr) begin
      base_addr[1] <= track_2_addr;
      length[1] <= track_2_length;
      loop[1] <= track_2_loop;
      counter[1] <= 32'd0;
    end

    if (track_2_start) begin
      active[1] <= 1'b1;
    end

    if (track_2_stop) begin
      active[1] <= 1'b0;
      sample[1] <= {4{8'd128}};
    end

    if (fetch_count[0] == 1'b0 && fetch_count[2:1] < 2'd2 && fetch) begin
      if (active[fetch_count[1]]) begin
        mem_addr <= base_addr[fetch_count[1]] + counter[fetch_count[1]];
        mem_cs <= 1'b1;
        fetch_count <= fetch_count + 3'd1;
        counter[fetch_count[1]] <= counter[fetch_count[1]] + 32'd1;
        if (counter[fetch_count[1]] == length[fetch_count[1]]) begin
          counter[fetch_count[1]] <= 32'd0;
          if (~loop[fetch_count[1]]) begin
            active[fetch_count[1]] <= 1'b0;
            sample[1] <= {4{8'd128}};
          end
        end
      end else begin
        fetch_count <= fetch_count + 3'd2;
      end
    end

    if (mem_ack) begin
      sample[fetch_count[1]][31:16] <= mem_dout[15:0];
      fetch_count <= fetch_count + 3'd1;
    end

    if (step == 8'd255) begin
      pulse <= pulse + 4'd1;
      if (pulse == 4'd8) begin
        pulse <= 4'd0;
        fetch <= ~fetch;
        fetch_count <= 3'd0;

        if (active[0]) begin
          sample[0] <= {{2{8'd128}}, sample[0][31:16]};
        end

        if (active[1]) begin
          sample[1] <= {{2{8'd128}}, sample[1][31:16]};
        end
      end
    end

    pwm <= (step <= (fetch ? low_final : high_final)) ? 1'b1 : 1'b0;
  end
end

endmodule

module sdram_controller(
  clk,
  res,
  addr,
  ba,
  cas_n,
  cke,
  cs_n,
  dq,
  dqm,
  ras_n,
  we_n,

  addr_in,
  data_in,
  // burst = 0 means read 1 word, burst = 511 means read 512 words
  burst,
  data_out,
  req,
  wr,
  ack
);

input clk;
input res;
output [12:0] addr;
output [1:0] ba;
output cas_n;
output cke;
output cs_n;
inout [15:0] dq;
output [1:0] dqm;
output ras_n;
output we_n;

input [23:0] addr_in;
input [15:0] data_in;
input [8:0] burst;
output [15:0] data_out;
input req;
input wr;
output ack;

`define STATE_INIT_NOP 4'd0
`define STATE_INIT_PRE 4'd1
`define STATE_INIT_REF 4'd2
`define STATE_INIT_MRS 4'd3
`define STATE_IDLE 4'd4
`define STATE_REF 4'd5
`define STATE_READ 4'd6
`define STATE_READ_WRAP 4'd7
`define STATE_WRITE 4'd8
`define STATE_WRITE_WRAP 4'd9

`define OPCODE_NOP 4'b0111
`define OPCODE_PRE 4'b0010
`define OPCODE_REF 4'b0001
`define OPCODE_MRS 4'b0000
`define OPCODE_ACT 4'b0011
`define OPCODE_READ 4'b0101
`define OPCODE_WRITE 4'b0100
`define OPCODE_BTERM 4'b0110

reg [14:0] count;
reg [9:0] refresh;
reg [3:0] state;

reg [12:0] addr;
reg [1:0] ba;
reg cke;
reg [15:0] dq;
reg [1:0] dqm;

assign data_out = dq;
reg ack;
wire wrap;
wire [9:0] job_length;
assign wrap = ((addr_in[8:0] + burst) & 10'h200) == 10'h200 ? 1'b1 : 1'b0;
assign job_length = (wr ? burst + 3'd4 : burst + 3'd5) +
                    (wrap ? (wr ? 3'd6 : 3'd7 ) : 1'd0);
wire [23:0] wrap_addr;
assign wrap_addr = { addr_in[23:9] + 1'b1, 9'd0 };
reg [8:0] before_wrap_count;
reg [8:0] after_wrap_count;

reg [3:0] opcode;

assign {cs_n, ras_n, cas_n, we_n} = opcode;

always @(posedge clk) begin
  count <= count + 1'b1;
  refresh <= refresh - 1'b1;
  ack <= 1'b0;

  if (res) begin
    addr <= {13{1'b0}};
    ba <= {2{1'b0}};
    cke <= 1'b1;
    dq <= {16{1'bZ}};
    dqm <= {2{1'b0}};
    state <= `STATE_INIT_NOP;
    opcode <= `OPCODE_NOP;
    count <= 15'd0;
    refresh <= 10'd779;
  end

  case (state)
    `STATE_INIT_NOP: begin
      if (count == 15'd19999) begin
        state <= `STATE_INIT_PRE;
        opcode <= `OPCODE_PRE;
        addr[10] <= 1'b1;
        count <= 15'd0;
      end
    end

    `STATE_INIT_PRE: begin
      opcode <= `OPCODE_NOP;
      addr[10] <= 1'b0;

      if (count[1:0] == 2'd2) begin
        state <= `STATE_INIT_REF;
        opcode <= `OPCODE_REF;
        count[1:0] <= 2'd0;
      end
    end

    `STATE_INIT_REF: begin
      if (count[2:0] == 3'd6) begin
        opcode <= `OPCODE_REF;
        count[2:0] <= 3'd0;
        count[5:3] <= count[5:3] + 1'b1;
      end else begin
        opcode <= `OPCODE_NOP;
      end

      if (count[5:0] == 6'b110110) begin
        state <= `STATE_INIT_MRS;
        addr[9:0] <= 10'b0_00_010_0_111;
        opcode <= `OPCODE_MRS;
        count[5:0] <= 6'd0;
      end
    end

    `STATE_INIT_MRS: begin
      opcode <= `OPCODE_NOP;
      addr[9:0] <= {10{1'b0}};

      if (count[1:0] == 2'd2) begin
        state <= `STATE_REF;
        opcode <= `OPCODE_REF;

        count[1:0] <= 2'd0;
      end
    end

    `STATE_IDLE: begin
      if (req && job_length < refresh) begin
        before_wrap_count <= 9'h1FF - addr_in[8:0];
        after_wrap_count <= (burst - (9'h1FF - addr_in[8:0])) - 9'd1;
        count <= 15'd0;

        ba <= addr_in[23:22];
        addr <= addr_in[21:9];
        dqm <= {2{1'b1}};

        if (wr) begin
          state <= `STATE_WRITE;
          opcode <= `OPCODE_ACT;
          ack <= 1'b1;
        end else begin
          state <= `STATE_READ;
          opcode <= `OPCODE_ACT;
        end
      end

      if (refresh == 0) begin
        state <= `STATE_REF;
        opcode <= `OPCODE_REF;
        count <= 15'd0;
      end
    end

    `STATE_REF: begin
      opcode <= `OPCODE_NOP;

      if (count[2:0] == 3'd6) begin
        state <= `STATE_IDLE;
        count[2:0] <= 3'd0;
        refresh <= 10'd779;
      end
    end

    `STATE_READ: begin
      opcode <= `OPCODE_NOP;

      if (count[9:0] == 10'd1) begin
        opcode <= `OPCODE_READ;
        addr[10] <= 1'b0;
        addr[8:0] <= addr_in[8:0];
        dqm <= {2{1'b0}};
      end

      if (count[9:0] >= 10'd3) begin
        ack <= 1'b1;
      end
      
      if (wrap) begin
        if (count[9:0] - 10'd2 == before_wrap_count) begin
          opcode <= `OPCODE_PRE;
          addr[10] <= 1'b1;
        end else if (count[9:0] - 10'd4 == before_wrap_count) begin
          state <= `STATE_READ_WRAP;
          opcode <= `OPCODE_ACT;
          count <= 15'd0;
          ba <= wrap_addr[23:22];
          addr <= wrap_addr[21:9];
          dqm <= {2{1'b1}};
          ack <= 1'd0;
        end
      end else begin
        if (count[9:0] == burst + 2'd2) begin
          opcode <= `OPCODE_PRE;
          addr[10] <= 1'b1;
        end else if (count[9:0] == burst + 3'd4) begin
          state <= `STATE_IDLE;
          count <= 10'd0;
          dqm <= {2{1'b1}};
          ack <= 1'b0;
        end
      end
    end

    `STATE_READ_WRAP: begin
      opcode <= `OPCODE_NOP;

      if (count[9:0] >= 10'd3) begin
        ack <= 1'b1;
      end

      if (count[9:0] == 10'd1) begin
        opcode <= `OPCODE_READ;
        addr[10] <= 1'b0;
        addr[8:0] <= wrap_addr[8:0];
        dqm <= {2{1'b0}};
      end else if (count[9:0] == after_wrap_count + 2'd2) begin
        opcode <= `OPCODE_PRE;
        addr[10] <= 1'b1;
      end else if (count[9:0] == after_wrap_count + 3'd4) begin
        state <= `STATE_IDLE;
        count <= 10'd0;
        dqm <= {2{1'b1}};
        ack <= 1'b0;
      end
    end

    `STATE_WRITE: begin
      opcode <= `OPCODE_NOP;

      if (count[9:0] == 10'd1) begin
        opcode <= `OPCODE_WRITE;
        addr[10] <= 1'b0;
        addr[8:0] <= addr_in[8:0];
        dqm <= {2{1'b0}};
      end

      if (count[9:0] >= 10'd1) begin
        dq <= data_in;
      end

      if (wrap) begin
        if (count[9:0] < before_wrap_count) begin
          ack <= 1'b1;
        end else if (count[9:0] - 10'd2 == before_wrap_count) begin
          opcode <= `OPCODE_PRE;
          addr[10] <= 1'b1;
          dq <= {16{1'bZ}};
        end else if (count[9:0] - 10'd4 == before_wrap_count) begin
          state <= `STATE_WRITE_WRAP;
          opcode <= `OPCODE_ACT;
          count <= 15'd0;
          ba <= wrap_addr[23:22];
          addr <= wrap_addr[21:9];
          dqm <= {2{1'b1}};
          dq <= {16{1'bZ}};
          ack <= 1'b1;
        end
      end else begin
        if (count[9:0] < burst) begin
          ack <= 1'b1;
        end else if (count[9:0] == burst + 2'd2) begin
          opcode <= `OPCODE_PRE;
          addr[10] <= 1'b1;
          dq <= {16{1'bZ}};
        end else if (count[9:0] == burst + 2'd3) begin
          state <= `STATE_IDLE;
          count <= 10'd0;
          dqm <= {2{1'b1}};
          dq <= {16{1'bZ}};
        end
      end
    end

    `STATE_WRITE_WRAP: begin
      opcode <= `OPCODE_NOP;

      if (count[9:0] == 10'd1) begin
        opcode <= `OPCODE_WRITE;
        addr[10] <= 1'b0;
        addr[8:0] <= wrap_addr[8:0];
        dqm <= {2{1'b0}};
      end

      if (count[9:0] >= 10'd1) begin
        dq <= data_in;
      end

      if (count[9:0] < after_wrap_count) begin
        ack <= 1'b1;
      end else if (count[9:0] == after_wrap_count + 2'd2) begin
        opcode <= `OPCODE_PRE;
        addr[10] <= 1'b1;
        dq <= {16{1'bZ}};
      end else if (count[9:0] == after_wrap_count + 2'd3) begin
        state <= `STATE_IDLE;
        count <= 10'd0;
        dqm <= {2{1'b1}};
        dq <= {16{1'bZ}};
      end
    end
  endcase
end

endmodule

module tpu_top #(
    parameter int N = 4
) (
    input logic clk,
    input logic rst_n,

    // Host CSR interface
    input logic [7:0] host_addr,
    input logic host_wr_en,
    input logic host_rd_en,
    input logic [31:0] host_wdata,
    output logic [31:0] host_rdata,

    // Streaming DMA input
    input logic dma_valid,
    output logic dma_ready,
    input logic [31:0] dma_data
);

  import tpu_pkg::*;

  // ------------------------------------------------------------
  // CSR
  // ------------------------------------------------------------

  logic instr_push;
  logic [31:0] instr_data;

  logic csr_ub_wr_en;
  logic [7:0] csr_ub_wr_addr;
  logic [31:0] csr_ub_wr_data;

  logic [7:0] result_rd_addr;

  logic signed [15:0]
      q_multiplier;

  logic [5:0]
      q_shift;

  logic signed [7:0]
      q_zero_point;

  logic [7:0]
      dma_base;

  logic dma_enable;

  logic [31:0]
      ub_host_rdata;

  logic [31:0]
      result_host_rdata;

  logic core_busy;
  logic core_done;

  // ------------------------------------------------------------
  // DMA
  // ------------------------------------------------------------

  logic dma_mem_wr_en;
  logic [7:0] dma_mem_wr_addr;
  logic [31:0] dma_mem_wr_data;

  dma_stream_if u_dma (

      .clk(clk),
      .rst_n(rst_n),

      .enable(dma_enable),
      .base_addr(dma_base),

      .stream_valid(dma_valid),
      .stream_ready(dma_ready),
      .stream_data(dma_data),

      .mem_wr_en(dma_mem_wr_en),
      .mem_wr_addr(dma_mem_wr_addr),
      .mem_wr_data(dma_mem_wr_data)
  );

  // ------------------------------------------------------------
  // Instruction queue
  // ------------------------------------------------------------

  logic instr_full;
  logic instr_empty;

  logic instr_pop;

  logic [31:0] instr_head;

  instr_queue #(
      .DEPTH(INSTR_DEPTH)
  ) u_instr_q (

      .clk(clk),
      .rst_n(rst_n),

      .push(instr_push),
      .push_data(instr_data),
      .full(instr_full),

      .pop(instr_pop),
      .head_data(instr_head),
      .empty(instr_empty),

      .count()
  );

  // ------------------------------------------------------------
  // Decoder
  // ------------------------------------------------------------

  logic [3:0] opcode;
  logic [7:0] addr_a;
  logic [7:0] addr_c;

  instr_decoder u_decoder (

      .instr(instr_head),

      .opcode(opcode),

      .addr_a(addr_a),
      .addr_c(addr_c)
  );

  // ------------------------------------------------------------
  // Unified buffer
  // ------------------------------------------------------------

  logic ub_wr_en;
  logic [7:0] ub_wr_addr;
  logic [31:0] ub_wr_data;

  logic ub_ctrl_wr_en;

  assign ub_wr_en =
      csr_ub_wr_en ||
      dma_mem_wr_en;

  assign ub_wr_addr =
      dma_mem_wr_en ?
      dma_mem_wr_addr :
      csr_ub_wr_addr;

  assign ub_wr_data =
      dma_mem_wr_en ?
      dma_mem_wr_data :
      csr_ub_wr_data;

  logic [7:0]
      ub_rd_addr [0:7];

  logic [31:0]
      ub_rd_data [0:7];

  unified_buffer #(
      .DEPTH(UB_DEPTH),
      .WORD_W(32),
      .RD_PORTS(8)
  ) u_ub (

      .clk(clk),
      .rst_n(rst_n),

      .wr_en(ub_wr_en),
      .wr_addr(ub_wr_addr),
      .wr_data(ub_wr_data),

      .rd_addr(ub_rd_addr),
      .rd_data(ub_rd_data),

      .host_rd_addr(
          host_addr
      ),

      .host_rd_data(
          ub_host_rdata
      )
  );

  // ------------------------------------------------------------
  // Weight FIFO
  // ------------------------------------------------------------

  logic wfifo_push;
  logic wfifo_pop;

  logic wfifo_full;
  logic wfifo_empty;

  logic [31:0] wfifo_push_data;
  logic [31:0] wfifo_pop_data;

  weight_fifo #(
      .WIDTH(32),
      .DEPTH(WEIGHT_DEPTH)
  ) u_weight_fifo (

      .clk(clk),
      .rst_n(rst_n),

      .push(wfifo_push),
      .push_data(wfifo_push_data),
      .full(wfifo_full),

      .pop(wfifo_pop),
      .pop_data(wfifo_pop_data),
      .empty(wfifo_empty),

      .count()
  );

  // ------------------------------------------------------------
  // Systolic array
  // ------------------------------------------------------------

  logic array_start;
  logic array_busy;
  logic array_done;

  logic signed [7:0]
      array_a_in [0:N-1];

  logic signed [7:0]
      array_b_in [0:N-1];

  logic signed [31:0]
      array_acc [0:N*N-1];

  systolic_array #(
      .N(N),
      .DATA_W(8),
      .ACC_W(32)
  ) u_array (

      .clk(clk),
      .rst_n(rst_n),

      .start(array_start),

      .a_in(array_a_in),
      .b_in(array_b_in),

      .busy(array_busy),
      .done(array_done),

      .acc_out(array_acc)
  );

  // ------------------------------------------------------------
  // Array controller
  // ------------------------------------------------------------

  logic result_valid;

  logic [7:0]
      result_addr;

  logic signed [31:0]
      result_acc;

  array_ctrl #(
      .N(N),
      .WORD_W(32),
      .ACC_W(32)
  ) u_ctrl (

      .clk(clk),
      .rst_n(rst_n),

      .instr_valid(!instr_empty),
      .instr_pop(instr_pop),

      .opcode(opcode),
      .addr_a(addr_a),
      .addr_c(addr_c),

      .ub_rd_valid(),
      .ub_rd_addr(ub_rd_addr),
      .ub_rd_data(ub_rd_data),

      .wfifo_push(wfifo_push),
      .wfifo_push_data(wfifo_push_data),
      .wfifo_full(wfifo_full),

      .wfifo_pop(wfifo_pop),
      .wfifo_pop_data(wfifo_pop_data),
      .wfifo_empty(wfifo_empty),

      .array_start(array_start),

      .array_a_in(array_a_in),
      .array_b_in(array_b_in),

      .array_busy(array_busy),
      .array_done(array_done),
      .array_acc(array_acc),

      .result_valid(result_valid),
      .result_addr(result_addr),
      .result_acc(result_acc),

      .busy(core_busy),
      .done(core_done)
  );

  // ------------------------------------------------------------
  // Requantization
  // ------------------------------------------------------------

  logic signed [7:0]
      requant_data;

  requantize_unit u_requant (

      .acc(result_acc),

      .multiplier(q_multiplier),

      .shift(q_shift),

      .zero_point(q_zero_point),

      .out_data(requant_data)
  );

  // ------------------------------------------------------------
  // Result buffer
  // ------------------------------------------------------------

  result_buffer #(
      .DEPTH(RESULT_DEPTH)
  ) u_result (

      .clk(clk),
      .rst_n(rst_n),

      .wr_en(result_valid),
      .wr_addr(result_addr),
      .wr_data(requant_data),

      .host_addr(result_rd_addr),
      .host_data(result_host_rdata)
  );

  // ------------------------------------------------------------
  // CSR
  // ------------------------------------------------------------

  csr_block u_csr (

      .clk(clk),
      .rst_n(rst_n),

      .host_addr(host_addr),
      .host_wr_en(host_wr_en),
      .host_rd_en(host_rd_en),
      .host_wdata(host_wdata),
      .host_rdata(host_rdata),

      .instr_push(instr_push),
      .instr_data(instr_data),

      .ub_wr_en(csr_ub_wr_en),
      .ub_wr_addr(csr_ub_wr_addr),
      .ub_wr_data(csr_ub_wr_data),

      .result_rd_addr(result_rd_addr),

      .q_multiplier(q_multiplier),
      .q_shift(q_shift),
      .q_zero_point(q_zero_point),

      .dma_base(dma_base),
      .dma_enable(dma_enable),

      .ub_host_rdata(ub_host_rdata),
      .result_host_rdata(result_host_rdata),

      .core_busy(core_busy),
      .core_done(core_done),
      .instr_full(instr_full)
  );

endmodule

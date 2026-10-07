module unified_buffer #(
    parameter int DEPTH = 256,
    parameter int WORD_W = 32,
    parameter int RD_PORTS = 8
) (
    input logic clk,
    input logic rst_n,

    input logic wr_en,
    input logic [7:0] wr_addr,
    input logic [WORD_W-1:0] wr_data,

    input logic [7:0]
        rd_addr [0:RD_PORTS-1],

    output logic [WORD_W-1:0]
        rd_data [0:RD_PORTS-1],

    input logic [7:0] host_rd_addr,
    output logic [WORD_W-1:0] host_rd_data
);

  logic [WORD_W-1:0]
      mem [0:DEPTH-1];

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      for (int i = 0; i < DEPTH; i = i + 1)
        mem[i] <= '0;

    end
    else if (wr_en) begin

      mem[wr_addr] <= wr_data;

    end

  end

  always_comb begin

    for (int i = 0; i < RD_PORTS; i = i + 1)
      rd_data[i] = mem[rd_addr[i]];

    host_rd_data = mem[host_rd_addr];

  end

endmodule

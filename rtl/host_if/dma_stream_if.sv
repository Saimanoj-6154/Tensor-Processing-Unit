module dma_stream_if #(
    parameter int ADDR_W = 8,
    parameter int DATA_W = 32
) (
    input logic clk,
    input logic rst_n,

    input logic enable,
    input logic [ADDR_W-1:0] base_addr,

    input logic stream_valid,
    output logic stream_ready,
    input logic [DATA_W-1:0] stream_data,

    output logic mem_wr_en,
    output logic [ADDR_W-1:0] mem_wr_addr,
    output logic [DATA_W-1:0] mem_wr_data
);

  logic [ADDR_W-1:0] current_addr;

  assign stream_ready =
      enable;

  assign mem_wr_en =
      enable &&
      stream_valid;

  assign mem_wr_addr =
      current_addr;

  assign mem_wr_data =
      stream_data;

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      current_addr <= '0;

    end
    else if (enable &&
             stream_valid &&
             stream_ready) begin

      current_addr <=
          current_addr + 1'b1;

    end
    else if (!enable) begin

      current_addr <=
          base_addr;

    end

  end

endmodule

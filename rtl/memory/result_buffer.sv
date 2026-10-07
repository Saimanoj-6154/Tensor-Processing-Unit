module result_buffer #(
    parameter int DEPTH = 256
) (
    input logic clk,
    input logic rst_n,

    input logic wr_en,
    input logic [7:0] wr_addr,
    input logic signed [7:0] wr_data,

    input logic [7:0] host_addr,
    output logic [31:0] host_data
);

  logic signed [7:0]
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

    host_data =
        {{24{mem[host_addr][7]}},
         mem[host_addr]};

  end

endmodule

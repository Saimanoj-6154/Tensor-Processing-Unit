module pe #(
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic clk,
    input  logic rst_n,

    input  logic clear,
    input  logic enable,

    input  logic signed [DATA_W-1:0] a_in,
    input  logic signed [DATA_W-1:0] b_in,

    output logic signed [DATA_W-1:0] a_out,
    output logic signed [DATA_W-1:0] b_out,

    output logic signed [ACC_W-1:0] acc_out
);

  logic signed [2*DATA_W-1:0] mult;

  always_comb begin
    mult = a_in * b_in;
  end

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      a_out  <= '0;
      b_out  <= '0;
      acc_out <= '0;

    end
    else begin

      if (clear) begin

        a_out   <= '0;
        b_out   <= '0;
        acc_out <= '0;

      end
      else if (enable) begin

        a_out <= a_in;
        b_out <= b_in;

        acc_out <= acc_out +
                   {{(ACC_W-(2*DATA_W)){mult[2*DATA_W-1]}},
                    mult};

      end

    end

  end

endmodule

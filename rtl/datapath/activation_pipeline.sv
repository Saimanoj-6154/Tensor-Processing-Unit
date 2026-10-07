module activation_pipeline #(
    parameter bit ENABLE_RELU = 1'b0
) (
    input logic signed [7:0] in_data,

    input logic signed [7:0]
        zero_point,

    output logic signed [7:0] out_data
);

  logic signed [8:0] centered;

  always_comb begin

    centered =
        $signed(in_data) -
        $signed(zero_point);

    if (ENABLE_RELU &&
        centered < 0) begin

      out_data = 8'sd0;

    end
    else if (centered > 127) begin

      out_data = 8'sd127;

    end
    else if (centered < -128) begin

      out_data = -8'sd128;

    end
    else begin

      out_data =
          centered[7:0];

    end

  end

endmodule

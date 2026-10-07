module requantize_unit (
    input logic signed [31:0] acc,

    input logic signed [15:0]
        multiplier,

    input logic [5:0]
        shift,

    input logic signed [7:0]
        zero_point,

    output logic signed [7:0]
        out_data
);

  logic signed [47:0] product;
  logic signed [47:0] rounded;
  logic signed [47:0] shifted;
  logic signed [47:0] quantized;

  always_comb begin

    product =
        acc * multiplier;

    rounded = product;

    if (shift != 0) begin

      if (product >= 0)
        rounded =
            product +
            (48'sd1 <<< (shift-1));
      else
        rounded =
            product -
            (48'sd1 <<< (shift-1));

    end

    shifted =
        rounded >>> shift;

    quantized =
        shifted +
        zero_point;

    if (quantized > 127)

      out_data = 8'sd127;

    else if (quantized < -128)

      out_data = -8'sd128;

    else

      out_data =
          quantized[7:0];

  end

endmodule

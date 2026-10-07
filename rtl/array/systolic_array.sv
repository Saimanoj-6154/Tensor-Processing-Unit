module systolic_array #(
    parameter int N       = 4,
    parameter int DATA_W  = 8,
    parameter int ACC_W   = 32
) (
    input logic clk,
    input logic rst_n,

    input logic start,

    input logic signed [DATA_W-1:0]
        a_in [0:N-1],

    input logic signed [DATA_W-1:0]
        b_in [0:N-1],

    output logic busy,
    output logic done,

    output logic signed [ACC_W-1:0]
        acc_out [0:N*N-1]
);

  localparam int TOTAL_CYCLES =
      (3*N) - 2;

  localparam int CW =
      (TOTAL_CYCLES <= 2) ? 1 : $clog2(TOTAL_CYCLES);

  logic [CW-1:0] cycle_count;

  logic pe_enable;
  logic pe_clear;

  logic signed [DATA_W-1:0]
      a_pipe [0:N-1][0:N-1];

  logic signed [DATA_W-1:0]
      b_pipe [0:N-1][0:N-1];

  genvar r;
  genvar c;

  generate

    for (r = 0; r < N; r = r + 1) begin : GEN_R

      for (c = 0; c < N; c = c + 1) begin : GEN_C

        wire signed [DATA_W-1:0]
            pe_a_in;

        wire signed [DATA_W-1:0]
            pe_b_in;

        if (c == 0) begin : A_EDGE

          assign pe_a_in = a_in[r];

        end
        else begin : A_PIPE

          assign pe_a_in =
              a_pipe[r][c-1];

        end

        if (r == 0) begin : B_EDGE

          assign pe_b_in = b_in[c];

        end
        else begin : B_PIPE

          assign pe_b_in =
              b_pipe[r-1][c];

        end

        pe #(
            .DATA_W(DATA_W),
            .ACC_W(ACC_W)
        ) u_pe (

            .clk(clk),
            .rst_n(rst_n),

            .clear(pe_clear),
            .enable(pe_enable),

            .a_in(pe_a_in),
            .b_in(pe_b_in),

            .a_out(a_pipe[r][c]),
            .b_out(b_pipe[r][c]),

            .acc_out(
                acc_out[r*N+c]
            )
        );

      end

    end

  endgenerate

  assign pe_enable = busy;
  assign pe_clear  = start;

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      busy       <= 1'b0;
      done       <= 1'b0;
      cycle_count <= '0;

    end
    else begin

      done <= 1'b0;

      if (start) begin

        busy        <= 1'b1;
        cycle_count <= '0;

      end
      else if (busy) begin

        if (cycle_count ==
            TOTAL_CYCLES-1) begin

          busy        <= 1'b0;
          done        <= 1'b1;
          cycle_count <= '0;

        end
        else begin

          cycle_count <=
              cycle_count + 1'b1;

        end

      end

    end

  end

endmodule

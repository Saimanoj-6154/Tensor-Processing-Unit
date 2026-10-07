module array_ctrl #(
    parameter int N          = 4,
    parameter int WORD_W     = 32,
    parameter int ACC_W      = 32
) (
    input logic clk,
    input logic rst_n,

    input logic instr_valid,
    output logic instr_pop,

    input logic [3:0] opcode,
    input logic [7:0] addr_a,
    input logic [7:0] addr_c,

    output logic ub_rd_valid,
    output logic [7:0]
        ub_rd_addr [0:7],

    input logic [31:0]
        ub_rd_data [0:7],

    output logic wfifo_push,
    output logic [31:0] wfifo_push_data,

    input logic wfifo_full,

    output logic wfifo_pop,

    input logic [31:0] wfifo_pop_data,

    input logic wfifo_empty,

    output logic array_start,

    output logic signed [7:0]
        array_a_in [0:N-1],

    output logic signed [7:0]
        array_b_in [0:N-1],

    input logic array_busy,
    input logic array_done,

    input logic signed [ACC_W-1:0]
        array_acc [0:N*N-1],

    output logic result_valid,
    output logic [7:0] result_addr,
    output logic signed [ACC_W-1:0] result_acc,

    output logic busy,
    output logic done
);

  import tpu_pkg::*;

  typedef enum logic [3:0] {
    S_IDLE,
    S_W_PUSH,
    S_W_POP,
    S_START,
    S_COMPUTE,
    S_STORE,
    S_HALT
  } state_t;

  state_t state;

  logic [7:0] base_addr;
  logic [7:0] result_base;

  logic [2:0] index;

  logic signed [7:0]
      weight_cache [0:N-1][0:N-1];

  logic weights_valid;

  logic signed [7:0] act_value;

  integer row;
  integer col;
  integer k;

  always_comb begin

    for (int i = 0; i < 8; i = i + 1)
      ub_rd_addr[i] = '0;

    ub_rd_valid = 1'b0;

    wfifo_push      = 1'b0;
    wfifo_push_data = '0;

    wfifo_pop = 1'b0;

    array_start = 1'b0;

    for (int i = 0; i < N; i = i + 1) begin
      array_a_in[i] = '0;
      array_b_in[i] = '0;
    end

    result_valid = 1'b0;
    result_addr  = '0;
    result_acc   = '0;

    instr_pop = 1'b0;

    busy = 1'b0;

    done = 1'b0;

    if (state != S_IDLE &&
        state != S_HALT)

      busy = 1'b1;

    case (state)

      S_IDLE: begin

        if (instr_valid) begin

          case (opcode)

            OP_LOAD_WEIGHT: begin

              if (!wfifo_full) begin
                instr_pop = 1'b1;
              end

            end

            OP_MATMUL: begin

              if (weights_valid) begin
                instr_pop = 1'b1;
              end

            end

            OP_HALT: begin

              instr_pop = 1'b1;
            end

            default: begin
              instr_pop = 1'b1;
            end

          endcase

        end

      end

      S_W_PUSH: begin

        ub_rd_valid = 1'b1;

        ub_rd_addr[index] =
            base_addr + index;

        if (!wfifo_full) begin

          wfifo_push = 1'b1;

          wfifo_push_data =
              ub_rd_data[index];

        end

      end

      S_W_POP: begin

        if (!wfifo_empty)
          wfifo_pop = 1'b1;

      end

      S_START: begin

        array_start = 1'b1;
      end

      S_COMPUTE: begin

        // Four words starting at base_addr hold
        // four rows of INT8 activation data.

        for (row = 0;
             row < N;
             row = row + 1) begin

          k = $signed(index) - row;

          if ((k >= 0) && (k < N)) begin

            act_value =
                $signed(
                  ub_rd_data[row]
                  [k*8 +: 8]
                );

            array_a_in[row] =
                act_value;

          end
          else begin

            array_a_in[row] = '0;

          end

        end

        // Weight cache contains B[k][column].
        // B elements are injected from the north.

        for (col = 0;
             col < N;
             col = col + 1) begin

          k = $signed(index) - col;

          if ((k >= 0) && (k < N))

            array_b_in[col] =
                weight_cache[k][col];

          else

            array_b_in[col] = '0;

        end

        for (row = 0;
             row < N;
             row = row + 1)

          ub_rd_addr[row] =
              base_addr + row;

        ub_rd_valid = 1'b1;

      end

      S_STORE: begin

        result_valid = 1'b1;

        result_addr =
            result_base + index;

        result_acc =
            array_acc[index];

      end

      default: begin

      end

    endcase

  end

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      state <= S_IDLE;

      base_addr   <= '0;
      result_base <= '0;

      index <= '0;

      weights_valid <= 1'b0;

      for (int i = 0; i < N; i = i + 1)
        for (int j = 0; j < N; j = j + 1)
          weight_cache[i][j] <= '0;

    end
    else begin

      case (state)

        S_IDLE: begin

          if (instr_valid && instr_pop) begin

            case (opcode)

              OP_LOAD_WEIGHT: begin

                base_addr <= addr_a;
                index <= 0;
                state <= S_W_PUSH;

                weights_valid <= 1'b0;

              end

              OP_MATMUL: begin

                base_addr <= addr_a;
                result_base <= addr_c;

                index <= 0;

                state <= S_START;

              end

              OP_HALT: begin

                state <= S_HALT;
              end

              default: begin
                state <= S_IDLE;
              end

            endcase

          end

        end

        S_W_PUSH: begin

          if (!wfifo_full) begin

            if (index == N-1) begin

              index <= 0;
              state <= S_W_POP;

            end
            else begin

              index <= index + 1'b1;

            end

          end

        end

        S_W_POP: begin

          if (!wfifo_empty) begin

            weight_cache[index / N]
                           [index % N]
              <= $signed(
                   wfifo_pop_data[
                     ((index % N) * 8) +: 8
                   ]
                 );

            if (index == (N*N)-1) begin

              weights_valid <= 1'b1;

              index <= 0;

              state <= S_IDLE;

            end
            else begin

              index <= index + 1'b1;

            end

          end

        end

        S_START: begin

          index <= 0;
          state <= S_COMPUTE;
        end

        S_COMPUTE: begin

          if (array_done) begin

            index <= 0;
            state <= S_STORE;

          end
          else if (index ==
                   SYSTOLIC_CYCLES-1) begin

            // Keep the last driven systolic cycle active
            // until array_done is observed.

            index <= index;

          end
          else begin

            index <= index + 1'b1;

          end

        end

        S_STORE: begin

          if (index == (N*N)-1) begin

            index <= 0;
            state <= S_IDLE;

          end
          else begin

            index <= index + 1'b1;

          end

        end

        S_HALT: begin
          state <= S_HALT;
        end

        default: begin
          state <= S_IDLE;
        end

      endcase

    end

  end

endmodule

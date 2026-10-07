module csr_block (
    input logic clk,
    input logic rst_n,

    input logic [7:0] host_addr,
    input logic host_wr_en,
    input logic host_rd_en,
    input logic [31:0] host_wdata,
    output logic [31:0] host_rdata,

    output logic instr_push,
    output logic [31:0] instr_data,

    output logic ub_wr_en,
    output logic [7:0] ub_wr_addr,
    output logic [31:0] ub_wr_data,

    output logic [7:0] result_rd_addr,

    output logic signed [15:0]
        q_multiplier,

    output logic [5:0]
        q_shift,

    output logic signed [7:0]
        q_zero_point,

    output logic [7:0] dma_base,
    output logic dma_enable,

    input logic [31:0] ub_host_rdata,
    input logic [31:0] result_host_rdata,

    input logic core_busy,
    input logic core_done,
    input logic instr_full
);

  logic done_latched;

  assign instr_push =
      host_wr_en &&
      (host_addr == 8'h04) &&
      !instr_full;

  assign instr_data =
      host_wdata;

  assign ub_wr_en =
      host_wr_en &&
      (host_addr == 8'h10);

  assign ub_wr_addr =
      host_wdata[7:0];

  assign ub_wr_data =
      host_wdata;

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      q_multiplier <= 16'sd1;
      q_shift     <= 6'd0;
      q_zero_point <= 8'sd0;

      dma_base   <= '0;
      dma_enable <= 1'b0;

      result_rd_addr <= '0;

      done_latched <= 1'b0;

    end
    else begin

      if (core_done)
        done_latched <= 1'b1;

      if (host_wr_en) begin

        case (host_addr)

          8'h18:
            q_multiplier <=
                $signed(host_wdata[15:0]);

          8'h1C:
            q_shift <=
                host_wdata[5:0];

          8'h20:
            q_zero_point <=
                $signed(host_wdata[7:0]);

          8'h24:
            dma_base <=
                host_wdata[7:0];

          8'h28:
            dma_enable <=
                host_wdata[0];

          8'h30:
            result_rd_addr <=
                host_wdata[7:0];

          8'h34:
            if (host_wdata[0])
              done_latched <= 1'b0;

          default:
            ;

        endcase

      end

    end

  end

  always_comb begin

    host_rdata = '0;

    if (host_rd_en) begin

      case (host_addr)

        8'h00: begin

          host_rdata[0] = core_busy;
          host_rdata[1] = done_latched;

        end

        8'h0C:
          host_rdata =
              ub_host_rdata;

        8'h30:
          host_rdata =
              result_host_rdata;

        default:
          host_rdata = '0;

      endcase

    end

  end

endmodule

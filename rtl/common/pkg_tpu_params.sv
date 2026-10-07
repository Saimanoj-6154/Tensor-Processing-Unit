package tpu_pkg;

  parameter int ARRAY_N       = 4;
  parameter int INT8_W        = 8;
  parameter int ACC_W         = 32;
  parameter int WORD_W        = 32;

  parameter int UB_DEPTH      = 256;
  parameter int RESULT_DEPTH  = 256;
  parameter int INSTR_DEPTH   = 8;
  parameter int WEIGHT_DEPTH  = 4;

  parameter int SYSTOLIC_CYCLES =
      (3 * ARRAY_N) - 2;

  typedef enum logic [3:0] {
    OP_NOP         = 4'h0,
    OP_LOAD_WEIGHT = 4'h1,
    OP_MATMUL      = 4'h2,
    OP_HALT        = 4'hF
  } opcode_t;

  function automatic logic signed [7:0]
  get_byte(
      input logic [31:0] word,
      input int index
  );

    logic [7:0] temp;

    temp = word[index*8 +: 8];
    return $signed(temp);

  endfunction

endpackage

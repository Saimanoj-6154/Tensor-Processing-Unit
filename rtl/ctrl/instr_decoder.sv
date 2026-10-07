module instr_decoder (
    input logic [31:0] instr,

    output logic [3:0] opcode,

    output logic [7:0] addr_a,

    output logic [7:0] addr_c
);

  always_comb begin

    opcode = instr[31:28];

    addr_a = instr[27:20];

    addr_c = instr[19:12];

  end

endmodule

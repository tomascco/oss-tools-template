`timescale 1ns/1ps

// counter: contador binário de WIDTH bits.
//
// - rst = 1: volta a zero na próxima borda de subida de clk (reset síncrono).
// - en  = 1: soma um a cada ciclo.
// - en  = 0: mantém o valor.
// - Depois do valor máximo (todos os bits em 1), volta a zero.
//
// rst tem prioridade sobre en.

module counter #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             en,
    output logic [WIDTH-1:0] q
);

    always_ff @(posedge clk) begin
        if (rst) begin
            q <= '0;
        end else if (en) begin
            // WIDTH'(1'b1) é a constante 1 com WIDTH bits, então a soma tem a
            // mesma largura de q (o Verilator avisa quando as larguras diferem).
            // A soma descarta o vai-um, então o overflow volta a zero sozinho.
            q <= q + WIDTH'(1'b1);
        end
    end
endmodule

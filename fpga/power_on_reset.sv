// power_on_reset: gera rst logo depois que a FPGA é configurada.
//
// - rst = 1 durante as primeiras CYCLES bordas de subida de clk depois da
//   configuração, e 0 para sempre depois disso.
//
// Só serve em FPGA: depende de o bitstream carregar o valor inicial de count
// ("= '0" abaixo). Um ASIC não tem valor de power-up, por isso este módulo
// fica em fpga/ e não em rtl/ (veja as regras de RTL no AGENTS.md).
//
// Uso num top da placa:
//   logic rst;
//   power_on_reset u_por (.clk(clk), .rst(rst));

module power_on_reset #(
    parameter int unsigned CYCLES = 16
) (
    input  logic clk,
    output logic rst
);
    // Bits para guardar os valores de 0 a CYCLES (count para em CYCLES).
    localparam int unsigned WIDTH = $clog2(CYCLES + 1);

    logic [WIDTH-1:0] count = '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= count + WIDTH'(1'b1);
        end
    end

    assign rst = (count != WIDTH'(CYCLES));
endmodule

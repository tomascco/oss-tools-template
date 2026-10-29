// blink_top: exemplo de top da placa. Os 16 LEDs mostram os bits mais
// significativos de um contador livre de 27 bits.
//
// Com o clock de 100 MHz, led[15] (bit 26) troca de estado a cada
// 2^26 / 100e6 = 0,67 s; cada LED à direita pisca duas vezes mais rápido.
// Ligue sw[0] para pausar a contagem.
//
// Os nomes das portas são os do fpga/nexys-a7.xdc.

module blink_top (
    input  logic        clk,
    input  logic [15:0] sw,
    output logic [15:0] led
);
    localparam int WIDTH = 27;

    logic             rst;
    logic [WIDTH-1:0] count;

    power_on_reset u_por (
        .clk(clk),
        .rst(rst)
    );

    counter #(
        .WIDTH(WIDTH)
    ) u_counter (
        .clk(clk),
        .rst(rst),
        .en (!sw[0]),
        .q  (count)
    );

    assign led = count[WIDTH-1-:16];
endmodule

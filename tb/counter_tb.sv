`timescale 1ns/1ps

// counter_tb: testbench do counter.
//
// É o modelo para os outros testbenches. Tem três partes:
//
//   1. Testes dirigidos: casos escolhidos a dedo, verificados com assert.
//   2. Teste aleatório: uma classe de transação com campos rand e uma
//      constraint gera os estímulos; um modelo de referência (uma função SV)
//      diz qual deveria ser a saída, ciclo a ciclo.
//   3. Cobertura funcional: um covergroup conta quais situações
//      interessantes foram exercitadas, e o resultado é impresso no fim.
//
// Como rodar:
//   make test counter            (semente 1)
//   SEED=7 make test counter     (outra semente)
//   make waves counter           (escreve build/counter.fst)
//
// Convenção de tempo: as entradas mudam 1 unidade de tempo depois da borda de
// subida do clock e são amostradas pelo DUT na borda seguinte. Assim nunca há
// corrida entre o testbench e os always_ff do DUT.

module counter_tb;

    // Largura pequena de propósito: com 4 bits o contador dá a volta a cada
    // 16 incrementos, então o overflow também aparece no teste aleatório.
    localparam int WIDTH = 4;
    localparam logic [WIDTH-1:0] MAX = '1;  // todos os bits em 1

    // Número de ciclos do teste aleatório.
    localparam int N_CYCLES = 2000;

    // -----------------------------------------------------------------------
    // Clock, sinais e DUT
    // -----------------------------------------------------------------------

    logic             clk = 1'b0;
    logic             rst;
    logic             en;
    logic [WIDTH-1:0] q;

    always #5 clk = ~clk;  // período de 10 unidades de tempo

    counter #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .en (en),
        .q  (q)
    );

    // Ondas: só são escritas quando o simulador recebe +dumpfile=<arquivo>
    // (o `make waves counter` faz isso).
    initial begin
        string dump_file;
        if ($value$plusargs("dumpfile=%s", dump_file) != 0) begin
            $dumpfile(dump_file);
            $dumpvars(0, counter_tb);
        end
    end

    // -----------------------------------------------------------------------
    // Parte 3 (declarada aqui porque step() faz a amostragem): cobertura
    // -----------------------------------------------------------------------

    // Verdadeiro no ciclo em que o contador está no máximo e vai incrementar,
    // ou seja, o ciclo em que acontece o overflow.
    logic overflow;
    assign overflow = en && !rst && (q == MAX);

    covergroup counter_cg;
        cp_en: coverpoint en;
        cp_rst: coverpoint rst;
        cp_overflow: coverpoint overflow {
            bins happened = {1'b1};
        }
        // Todas as combinações de en e rst (inclusive rst e en juntos, para
        // ver que rst tem prioridade).
        cx_en_rst: cross cp_en, cp_rst;
    endgroup

    counter_cg cg;

    // -----------------------------------------------------------------------
    // Auxiliares
    // -----------------------------------------------------------------------

    // Aplica rst/en, amostra a cobertura e espera o DUT reagir.
    task automatic step(input logic rst_i, input logic en_i);
        rst = rst_i;
        en  = en_i;
        cg.sample();  // amostra as entradas e o overflow deste ciclo
        @(posedge clk);
        #1;  // saída do flip-flop já estável
    endtask

    // Compara a saída com o valor esperado.
    task automatic check(input logic [WIDTH-1:0] expected, input string context_msg);
        assert (q == expected)
        else $fatal(1, "%s: esperado q=%0d, obtido q=%0d (t=%0t)", context_msg, expected, q, $time);
    endtask

    // -----------------------------------------------------------------------
    // Parte 1: testes dirigidos
    // -----------------------------------------------------------------------

    task automatic directed_tests();
        $display("[parte 1] testes dirigidos");

        // Reset: depois de um ciclo com rst=1, q é 0.
        step(1'b1, 1'b0);
        check('0, "reset");

        // Incremento: cada ciclo com en=1 soma 1.
        for (int i = 1; i <= 5; i++) begin
            step(1'b0, 1'b1);
            check(WIDTH'(i), "incremento");
        end

        // en=0 mantém o valor.
        for (int i = 0; i < 3; i++) begin
            step(1'b0, 1'b0);
            check(WIDTH'(5), "en=0 mantém o valor");
        end

        // rst tem prioridade sobre en.
        step(1'b1, 1'b1);
        check('0, "rst com en=1");

        // Overflow: conta até o máximo e confere que a soma seguinte dá 0.
        for (int i = 1; i <= int'(MAX); i++) begin
            step(1'b0, 1'b1);
        end
        check(MAX, "contou até o máximo");
        step(1'b0, 1'b1);
        check('0, "overflow volta a zero");
    endtask

    // -----------------------------------------------------------------------
    // Parte 2: teste aleatório com modelo de referência
    // -----------------------------------------------------------------------

    // Uma transação = os valores das entradas em um ciclo.
    class counter_txn;
        rand bit rst;
        rand bit en;

        // rst raro (1 a cada 20 ciclos, em média), para o contador ter tempo
        // de contar e chegar ao overflow entre um reset e outro.
        constraint c_rare_rst {
            rst dist {
                1'b1 := 1,
                1'b0 := 19
            };
        }
    endclass

    // Modelo de referência: o que o contador deve fazer, escrito do jeito
    // mais direto possível, sem pensar em hardware.
    function automatic logic [WIDTH-1:0] ref_model(input logic [WIDTH-1:0] current, input bit rst_i,
                                                   input bit en_i);
        if (rst_i) return '0;
        if (en_i) return current + WIDTH'(1);
        return current;
    endfunction

    task automatic random_test();
        counter_txn       txn;
        logic [WIDTH-1:0] expected;
        int               n_rst;

        $display("[parte 2] teste aleatório: %0d ciclos", N_CYCLES);
        txn      = new();
        expected = q;  // continua de onde a parte 1 parou
        n_rst    = 0;

        for (int cycle = 0; cycle < N_CYCLES; cycle++) begin
            assert (txn.randomize() == 1)
            else $fatal(1, "randomize() falhou no ciclo %0d", cycle);

            expected = ref_model(expected, txn.rst, txn.en);
            step(txn.rst, txn.en);
            check(expected, $sformatf("aleatório, ciclo %0d (rst=%0b en=%0b)", cycle, txn.rst, txn.en));
            n_rst += int'(txn.rst);
        end
        $display("[parte 2] %0d resets em %0d ciclos", n_rst, N_CYCLES);
    endtask

    // -----------------------------------------------------------------------
    // Sequência principal
    // -----------------------------------------------------------------------

    initial begin
        int seed;

        // A semente vem de +verilator+seed+N (o Makefile passa o SEED).
        // Imprimir a semente permite reproduzir uma falha exatamente.
        if ($value$plusargs("verilator+seed+%d", seed) == 0) seed = 0;
        $display("semente: %0d", seed);

        cg  = new();
        rst = 1'b1;
        en  = 1'b0;
        @(posedge clk);
        #1;

        directed_tests();
        random_test();

        $display("[parte 3] cobertura total: %0.1f%%", cg.get_coverage());

        // Cobertura de cada coverpoint separadamente. O Verilator 5.053 ainda
        // não aceita get_coverage() num coverpoint ("Unsupported: Member call
        // on object"), só no covergroup inteiro. Desativado até aceitar; para
        // experimentar (no xsim, por exemplo), defina COVERPOINT_REPORT.
`ifdef COVERPOINT_REPORT
        $display("[parte 3] en %0.1f%%, rst %0.1f%%, overflow %0.1f%%, en x rst %0.1f%%",
                 cg.cp_en.get_coverage(), cg.cp_rst.get_coverage(),
                 cg.cp_overflow.get_coverage(), cg.cx_en_rst.get_coverage());
`endif

        $display("PASS");
        $finish;
    end

endmodule

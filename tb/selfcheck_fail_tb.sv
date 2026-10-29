`timescale 1ns/1ps

// selfcheck_fail_tb: um teste que TEM que falhar.
//
// Existe para provar que o fluxo funciona: um assert que falha precisa
// terminar a simulação com código de saída diferente de zero, e o CI precisa
// ficar vermelho. O `make selfcheck` roda este teste e só passa se ele falhar.
//
// Não faz parte do `make test <módulo>`: só é chamado pelo `make selfcheck`
// (que o `make test` inclui).

module selfcheck_fail_tb;

    initial begin
        int expected;
        int actual;

        expected = 1;
        actual   = 2;
        assert (actual == expected)
        else $fatal(1, "falha proposital: esperado %0d, obtido %0d", expected, actual);

        // Nunca deveria chegar aqui.
        $display("PASS");
        $finish;
    end

endmodule

# Template HDL

Ambiente pronto para atividades de sistemas digitais em SystemVerilog: lint, testes com
asserts, testes aleatórios e cobertura, visualização de ondas, verificação de síntese e
geração de bitstream para a placa **Digilent Nexys A7-100T** (Artix-7 XC7A100T).

Tudo, exceto o bitstream, usa ferramentas abertas da
[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build), instaladas sem root dentro
do próprio repositório por um único comando. O bitstream é gerado pelo Yosys (síntese)
junto com o Vivado (place & route).

## Início rápido

1. **Instale e teste o ambiente** (só na primeira vez; baixa cerca de 700 MB):

   ```sh
   make setup
   ```

2. **Veja as ondas do exemplo**, um contador ([rtl/counter.sv](rtl/counter.sv)) com seu
   testbench ([tb/counter_tb.sv](tb/counter_tb.sv)):

   ```sh
   make waves counter
   ```

   Isso roda o teste, escreve `build/counter.fst` e abre no Surfer.

3. **Crie o seu módulo**: escreva `rtl/<módulo>.sv` e `tb/<módulo>_tb.sv`, usando o
   counter como modelo, e rode:

   ```sh
   make test <módulo>
   make waves <módulo>
   ```

   Não precisa mexer no Makefile: os arquivos novos são achados sozinhos. O passo a passo
   completo, até a placa, está em [Começando uma atividade](#começando-uma-atividade).

## Instalação

O host precisa só de `g++` (10 ou mais novo), `make` e `perl`, sem acesso de root.
Para o `make fpga`, também do Vivado (veja [Placa e bitstream](#placa-e-bitstream)).

```sh
make setup
```

É o único passo. Ele roda `make tools`, que baixa a OSS CAD Suite fixada no
`tools.lock` (cerca de 700 MB) para `.tools/`. Depois roda `make lint` e `make test` uma
vez, para provar que o fluxo funciona nesta máquina, e mostra os próximos passos.
Detalhes, como usar outro compilador ou instalar sem acesso ao GitHub, estão em
[docs/environment.md](docs/environment.md).

## Comandos

| Comando | O que faz |
|---|---|
| `make setup` | setup completo: `make tools`, `make lint` e `make test` |
| `make tools` | instala as ferramentas do `tools.lock` em `.tools/` |
| `make tools-prune` | apaga versões da OSS CAD Suite diferentes da do `tools.lock` (pede confirmação; aceita `KEEP="data1 data2"` e `YES=1`) |
| `make lint` | lint de todo o RTL: Verilator `-Wall` e elaboração com sv-elab |
| `make lint <módulo>` | lint de um módulo, por exemplo `make lint counter` |
| `make test` | roda todos os testbenches, mais o `selfcheck`; para na primeira falha |
| `make test <módulo>` | roda um testbench, por exemplo `make test counter` |
| `make selfcheck` | confirma que um `assert` que falha dá código de saída diferente de zero |
| `make synth` | verifica a síntese com o Yosys (`synth_xilinx`); relatório em `build/synth/` |
| `make synth <módulo>` | verifica a síntese de um módulo |
| `make waves <módulo>` | roda o testbench, escreve `build/<módulo>.fst` e abre no Surfer |
| `VIEWER=gtkwave make waves <módulo>` | abre no GTKWave; `VIEWER=` só escreve o arquivo |
| `make fpga` | gera o bitstream de todos os designs em `fpga/` e mostra um resumo (clock máximo, utilização) |
| `make fpga <design>` | gera um design, por exemplo `make fpga blink` (top `fpga/blink_top.sv`) |
| `make clean` | apaga `build/` |
| `SEED=N make test` | troca a semente dos testes aleatórios (padrão 1) |

Os alvos acham sozinhos os módulos em `rtl/`, os testbenches em `tb/` e os designs em
`fpga/`. Arquivos que ainda não declaram um `module` ou `package` são ignorados; assim
que um deles ganha uma assinatura, entra no lint, na síntese e nos testes sem nenhuma
mudança no Makefile.

`lint`, `test`, `synth`, `waves` e `fpga` aceitam vários nomes de uma vez
(`make test counter outro`). Para completar nomes com TAB no bash e no fish, veja
[docs/environment.md](docs/environment.md#completar-com-tab).

## Estrutura

```
rtl/            RTL sintetizável: um módulo por arquivo, nome do arquivo = nome do módulo
rtl/pkg/        packages (compilados antes dos módulos)
tb/             testbenches: tb/<módulo>_tb.sv, com top <módulo>_tb
sva/            assertions SVA em módulos separados, ligados com bind
fpga/           tops da placa (<design>_top.sv), módulos só de FPGA e os pinos (nexys-a7.xdc)
scripts/        instalação das ferramentas, fluxo do Vivado e completar com TAB
docs/           documentação do ambiente
build/          tudo o que é gerado (ignorado pelo git)
.tools/         ferramentas instaladas pelo make tools (ignorado pelo git)
```

## Começando uma atividade

1. Escreva o módulo em `rtl/<módulo>.sv`. Exemplo: [rtl/counter.sv](rtl/counter.sv).
2. Escreva o testbench em `tb/<módulo>_tb.sv`, a partir do modelo
   [tb/counter_tb.sv](tb/counter_tb.sv), que tem testes dirigidos, um teste aleatório
   com modelo de referência e cobertura funcional. O teste passa quando imprime `PASS` e
   chama `$finish`; qualquer `assert` que falha reprova.
3. `make lint <módulo>`, `make test <módulo>`, `make waves <módulo>` e
   `make synth <módulo>`.
4. Para rodar na placa, crie `fpga/<design>_top.sv`, que instancia o módulo e usa os
   nomes de porta do [fpga/nexys-a7.xdc](fpga/nexys-a7.xdc) (`clk`, `sw[15:0]`,
   `led[15:0]`, `btnc`, `seg[6:0]`, `an[7:0]`...). Exemplo:
   [fpga/blink_top.sv](fpga/blink_top.sv). Depois, `make fpga <design>`.

As regras de estilo do RTL e dos testbenches estão no [AGENTS.md](AGENTS.md).

## Placa e bitstream

O `make fpga` sintetiza o top com o Yosys (`synth_xilinx`, netlist EDIF) e chama o
Vivado em modo batch para place & route e bitstream
([scripts/vivado-impl.tcl](scripts/vivado-impl.tcl)). O resultado fica em
`build/fpga/<design>.bit`, junto com os relatórios de timing e utilização. Se algum
clock não fecha timing, o resumo mostra FAIL e o bitstream não é gerado.

O Vivado é procurado no `PATH` e nos lugares de instalação mais comuns; para outro lugar,
use `make fpga VIVADO=/caminho/bin/vivado`. Ele só é necessário para o `make fpga`: o
resto do fluxo, e o CI, funciona sem ele.

Gravar a placa não faz parte do fluxo. Para isso, abra o Hardware Manager do Vivado e
programe o `build/fpga/<design>.bit`.

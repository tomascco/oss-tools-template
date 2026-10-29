# Template HDL

Ambiente para atividades de sistemas digitais em SystemVerilog, com lint, testes, ondas,
síntese e bitstream para a placa Digilent Nexys A7-100T. É usado para ensino: prefira
código legível e didático a código esperto, e comente o porquê das decisões.

## Ferramentas

Toda a pilha de simulação e síntese vem da **OSS CAD Suite**, numa release de data fixa
definida no `tools.lock` e instalada sem root pelo `make tools` em `.tools/`, dentro do
próprio repositório (ignorado pelo git). Nada persistente é escrito fora do repositório.
Não instale ferramentas por pacotes do sistema nem por outro caminho. O host só precisa
de `g++`, `make` e `perl` (o executável `verilator` é um script Perl).

- **Verilator 5.052 ou mais novo** é o único simulador do fluxo automático. Versões mais
  velhas não têm covergroups (5.050+) nem UVM 2020-3.2 (5.052).
- **z3** (vem com a OSS CAD Suite): o Verilator chama um solver SMT durante a execução para
  `randomize()` com constraints.
- **Yosys** com o frontend **sv-elab** (antigo yosys-slang, comando `read_slang`), usado
  como segundo lint, pelas mensagens de erro melhores, e para verificar se o RTL é
  sintetizável (`synth_xilinx`). Vem embutido a partir do Yosys 0.67; em versões
  anteriores, carregue o plugin com `yosys -m slang`. Não use `read_verilog -sv` no RTL.
- **Vivado**, só no `make fpga`: recebe o netlist EDIF do Yosys e faz place & route e
  bitstream em modo batch (`scripts/vivado-impl.tcl`). Não é instalado pelo `make tools`
  e não está no CI. A síntese continua sendo do Yosys.
- **Não use cocotb nem Python** nos testes. Os testbenches são escritos em SystemVerilog.

## Regras do RTL (`rtl/`)

- Use: `logic`, `always_ff`, `always_comb`, `enum`, `typedef`, `package`.
- Não use:
  - classes (não sintetizáveis);
  - atrasos com `#` (a síntese ignora, e a simulação passa a divergir do hardware);
  - `initial` para dar valor a registradores (um ASIC não tem valor de power-up; use
    `rst`). Exceção: inicializar uma ROM ou BRAM de FPGA com `$readmemh`.
- Reset síncrono, ativo em nível alto, sinal `rst`; clock `clk`.
- Um módulo por arquivo, nome do arquivo = nome do módulo. Packages em `rtl/pkg/`.
- O RTL nunca conhece os pinos da placa. Os tops da placa ficam em
  `fpga/<design>_top.sv` (top `<design>_top`), com os pinos em `fpga/nexys-a7.xdc`. Os
  nomes das portas do top precisam ser os do XDC. Módulos só de FPGA usados por vários
  designs, como o `power_on_reset`, ficam em `fpga/` (sem o sufixo `_top`); eles podem
  depender de valores iniciais, o que `rtl/` não pode.
- Assertions SVA podem ficar no RTL dentro de `` `ifndef SYNTHESIS ``, ou num módulo
  separado em `sva/` ligado com `bind` (preferido).
- Todo RTL deve passar no `make lint` (Verilator `-Wall`) e no `make synth` sem avisos
  novos.

## Regras dos testbenches (`tb/`)

- Um testbench por módulo: `tb/<módulo>_tb.sv`, top `<módulo>_tb`
  (por exemplo `tb/counter_tb.sv`, módulo `counter_tb`). O modelo é o `tb/counter_tb.sv`.
- As verificações usam `assert (cond) else $fatal(1, "mensagem com valores esperado/obtido");`.
- O sucesso termina com `$display("PASS");` seguido de `$finish;`. O código de saída do
  simulador é o veredito do CI.
- Classes, `rand`, constraints e covergroups são permitidos aqui (e só aqui).
- Testes aleatórios recebem a semente por `+verilator+seed+N` e imprimem a semente usada.

## Comandos

- `make setup`: setup completo (`make tools`, `make lint` e `make test`).
- `make tools`: instala as ferramentas fixadas no `tools.lock` (só na primeira vez).
- `make tools-prune`: apaga, depois de confirmar, versões da OSS CAD Suite diferentes da
  do `tools.lock`. Nunca rode automaticamente.
- `make lint`: lint de todo o RTL (Verilator `-Wall` e elaboração com sv-elab).
- `make test`: roda todos os testbenches.
- `make test <módulo>`: roda um testbench (`lint`, `synth`, `waves` e `fpga` também
  aceitam nomes; vários são permitidos).
- `make synth`: verifica a síntese com o Yosys.
- `make waves <módulo>`: roda com dump FST e abre no Surfer (`VIEWER=gtkwave` ou
  `VIEWER=` para trocar ou não abrir o visualizador).
- `make fpga [design]`: síntese (Yosys), place & route e bitstream (Vivado) para a
  Nexys A7-100T, com um resumo de clock máximo e utilização.
- `scripts/completion/`: completar com TAB no bash e no fish (veja `docs/environment.md`).
- `SEED=N make test`: troca a semente.

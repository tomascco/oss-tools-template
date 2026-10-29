# Ambiente de desenvolvimento

Detalhes sobre o host e as ferramentas que o [README](../README.md) deixa de fora.

## Pré-requisitos do host

- `g++` 10 ou mais novo (ou `clang++` 5 ou mais novo). O Verilator usa corrotinas do C++20
  para o `--timing`.
- `make`.
- `perl`, porque o executável `verilator` é um script Perl.
- Opcional: `ccache`. Se estiver no PATH, o Makefile usa automaticamente (veja [ccache](#ccache)).
- Só para o `make fpga`: Vivado (veja [Vivado](#vivado)).

Não é preciso acesso de root. Se o compilador do sistema for velho demais, o
`make tools` lista as alternativas: um `gcc-toolset` já instalado pelo administrador, ou o
`gxx` do conda-forge via micromamba. Para escolher outro compilador:

```sh
CXX=/opt/rh/gcc-toolset-12/root/usr/bin/g++ make tools
CXX=/opt/rh/gcc-toolset-12/root/usr/bin/g++ make test
```

## Como o `make tools` funciona

O `make tools` baixa a release da [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
fixada no `tools.lock`, confere o SHA-256 e extrai em `.tools/` (dentro do repositório,
ignorado pelo git). Depois disso, o `make test` funciona de qualquer shell, fish incluído,
sem ativar ambiente nenhum: o próprio Makefile põe `.tools/oss-cad-suite-<data>/bin` no
`PATH`. A suíte também traz o GTKWave e o Surfer, então não é preciso instalar nada à
parte para ver ondas.

- Rodar o `make tools` de novo não baixa nada.
- A instalação é atômica. Se for interrompida (Ctrl+C), nada fica pela metade; basta rodar
  de novo.
- **Sem acesso ao GitHub** (por exemplo, atrás de um proxy): baixe o `.tgz` em outra
  máquina e rode `TGZ=/caminho/oss-cad-suite-linux-x64-AAAAMMDD.tgz make tools`. O
  SHA-256 é conferido do mesmo jeito.
- Para manter as ferramentas fora do repositório (por exemplo, para compartilhar uma
  instalação entre vários clones), passe `TOOLS_ROOT=/outro/lugar` em todo comando.
- Para remover tudo, apague `.tools/`. Um `git clean -fdx` também apaga, e o próximo
  `make tools` baixa uns 700 MB de novo.

Fixada hoje: **2026-10-20**, com Verilator 5.053 (devel, depois do 5.052),
Yosys 0.70+176 e z3 4.15.5. O frontend **sv-elab** (`read_slang`) vem **embutido** no
Yosys, então o Makefile não precisa de `-m slang`. O Makefile detecta os dois casos
(embutido ou plugin) e falha com uma mensagem clara se o `read_slang` faltar.
Ele nunca cai para `read_verilog -sv`. Para fixar outra versão, veja
[Atualizando a pilha](#atualizando-a-pilha).

## Atualizando a pilha

1. Escolha uma data em <https://github.com/YosysHQ/oss-cad-suite-build/releases>.
2. Baixe o `.tgz` linux-x64 dela e rode `sha256sum` nele.
3. Troque `OSS_CAD_SUITE_DATE` e `OSS_CAD_SUITE_SHA256` no `tools.lock`.
4. Rode `make tools`.

A versão antiga continua em `.tools/`, porque outro branch pode estar fixado nela. Para
apagá-la, rode `make tools-prune`.

## Vivado

O `make fpga` é o único alvo que usa o Vivado, e só para place & route e bitstream. A
síntese é do Yosys (`synth_xilinx`), que entrega um netlist EDIF
(`build/fpga/<design>_top.edf`); o [scripts/vivado-impl.tcl](../scripts/vivado-impl.tcl)
lê esse netlist e os pinos de `fpga/nexys-a7.xdc`, roda `opt_design`, `place_design` e
`route_design`, escreve os relatórios e, se o timing fecha, o bitstream.

- **Onde o Makefile procura:** no `PATH` e em `/tools/Xilinx`, `/opt/Xilinx` e
  `/tools/installs/Xilinx` (pega a versão mais nova). Para outro lugar:
  `make fpga VIVADO=/caminho/bin/vivado`. O `make help` mostra qual foi encontrado.
- **Versão e licença:** testado com o Vivado 2024.2. A XC7A100T é coberta pela edição
  gratuita (Vivado ML Standard).
- **Arquivos em `build/fpga/`:** `<design>.bit` (bitstream), `<design>-util.rpt`
  (utilização), `<design>-timing.rpt` (timing completo), `<design>-vivado.log` (log do
  Vivado) e `<design>-synth.log` (log do Yosys).
- **Pinos:** o XDC tem todos os pinos da placa ativos. Restrições de portas que não
  existem no top viram mensagens INFO. Já uma porta do top que não existe no XDC, como um
  nome digitado errado, faz o bitstream falhar no DRC (UCIO-1 ou NSTD-1), e o resumo mostra
  qual porta é.
- **Gravar a placa** não faz parte do fluxo: use o Hardware Manager do Vivado com o
  `build/fpga/<design>.bit`.

## ccache

Se o `ccache` estiver instalado, o Makefile o usa para compilar o C++ gerado pelo
Verilator. O cache fica em `.tools/ccache` e é limitado a 1 GB. Sem o `ccache`, nada muda.

## Completar com TAB

`scripts/completion/` tem completação para bash e fish: `make <TAB>` lista os alvos,
`make test <TAB>` os testbenches, `make lint <TAB>` os módulos do RTL e `make fpga <TAB>`
os designs. Dentro de um clone do template os nomes vêm direto de `rtl/`, `tb/` e
`fpga/`; em qualquer outro lugar o `make` mantém a completação de sempre. Nada é
instalado: basta uma linha na configuração do seu shell.

- **bash**, no `~/.bashrc` (depois de carregar o bash-completion):

  ```sh
  source /caminho/do/repositorio/scripts/completion/hdl.bash
  ```

- **fish**, no `~/.config/fish/config.fish`:

  ```fish
  set -p fish_complete_path /caminho/do/repositorio/scripts/completion
  ```

## Testbenches

O `tb/counter_tb.sv` é o modelo para os outros. Tem testes dirigidos, um teste aleatório
com uma classe `rand` e um modelo de referência, e um covergroup. As limitações do
Verilator encontradas até agora estão [abaixo](#limitações-do-verilator).

## Limitações do Verilator

Encontradas até agora com o Verilator 5.053:

- **`get_coverage()` por coverpoint não é suportado** ("Unsupported: Member call on
  object"). Só funciona o `get_coverage()` do covergroup inteiro. O relatório por
  coverpoint fica desativado atrás de `` `define COVERPOINT_REPORT `` no testbench.
- Mesmo sem `-Wall`, alguns avisos do Verilator são erros. Por exemplo, usar o valor de
  retorno do `randomize()` (um `int`) direto como condição dá `WIDTHTRUNC`: escreva
  `assert (obj.randomize() == 1)`.

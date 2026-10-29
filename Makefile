# Makefile do template HDL. `make help` lista os alvos.
#
# Todos os caminhos são relativos à raiz do repositório: rode o make daqui.

# ---------------------------------------------------------------------------
# Ferramentas
# ---------------------------------------------------------------------------

# tools.lock tem linhas CHAVE=valor, que o make lê como variáveis.
include tools.lock

# A OSS CAD Suite fica dentro do repositório, em .tools/ (ignorado pelo git).
TOOLS_ROOT ?= $(CURDIR)/.tools
TOOLS_DIR ?= $(TOOLS_ROOT)/oss-cad-suite-$(OSS_CAD_SUITE_DATE)

# Só o bin/ da OSS CAD Suite vai para o PATH (o script `environment` dela não
# é usado). Assim tudo funciona sem ativar nada, em qualquer shell.
export PATH := $(TOOLS_DIR)/bin:$(PATH)
export TOOLS_ROOT

# O executável `verilator` é um script Perl que precisa do módulo FindBin. O
# RHEL/Rocky 9 o distribui num pacote separado (perl-FindBin), que costuma
# faltar em máquinas sem root. Nesse caso usamos o substituto de scripts/perl5/.
ifeq ($(shell perl -MFindBin -e1 2>/dev/null && echo ok),)
  export PERL5LIB := $(CURDIR)/scripts/perl5$(if $(PERL5LIB),:$(PERL5LIB))
endif

# Compilador C++ usado pelo Verilator. Para trocar:
#   CXX=/opt/rh/gcc-toolset-12/root/usr/bin/g++ make test
CXX ?= g++

# Semente dos testes aleatórios. Para trocar: SEED=2 make test
SEED ?= 1

# Visualizador de ondas que o `make waves` abre ao fim da simulação. O Surfer
# vem com a OSS CAD Suite. VIEWER=gtkwave também funciona; VIEWER= (vazio)
# só escreve o .fst.
VIEWER ?= surfer

# O read_slang (sv-elab) vem embutido no Yosys 0.67 ou mais novo; antes disso
# é um plugin carregado com `yosys -m slang`. Detectamos qual é o caso aqui.
# Nunca caímos para `read_verilog -sv`: sem sv-elab, lint e synth falham.
YOSYS := $(TOOLS_DIR)/bin/yosys
SLANG_HELP_OK = $(shell $(YOSYS) $(1) -p 'help read_slang' 2>/dev/null | grep '^ *read_slang \[')
ifneq ($(wildcard $(YOSYS)),)
  ifneq ($(call SLANG_HELP_OK),)
    SLANG_MODE := builtin
    SLANG_LOAD :=
  else ifneq ($(call SLANG_HELP_OK,-m slang),)
    SLANG_MODE := plugin
    SLANG_LOAD := -m slang
  else
    SLANG_MODE := missing
  endif
endif

# Vivado: só o `make fpga` usa (place & route e bitstream). Não vem da OSS CAD
# Suite; procuramos no PATH e nos lugares de instalação mais comuns. Para
# outro lugar: make fpga VIVADO=/caminho/para/Vivado/<versão>/bin/vivado
VIVADO ?= $(or $(shell command -v vivado 2>/dev/null),$(lastword $(sort $(wildcard \
    /tools/Xilinx/Vivado/*/bin/vivado /tools/Xilinx/*/Vivado/bin/vivado \
    /opt/Xilinx/Vivado/*/bin/vivado /opt/Xilinx/*/Vivado/bin/vivado \
    /tools/installs/Xilinx/Vivado/*/bin/vivado))))

# ---------------------------------------------------------------------------
# Descoberta de arquivos
# ---------------------------------------------------------------------------

# Lista só os arquivos que já declaram um `module` ou `package`. Arquivos
# ainda vazios (ou só com `// TODO`) ficam de fora de todos os alvos; assim
# que o autor escreve a assinatura do módulo, ele entra sozinho em lint, synth
# e testes.
declares = $(shell grep -lE '^[[:space:]]*(module|package)[[:space:]]' $(1) /dev/null)

# Pacotes primeiro: os módulos dependem deles.
PKG_SRCS := $(call declares,$(wildcard rtl/pkg/*.sv))
MOD_SRCS := $(call declares,$(wildcard rtl/*.sv))
RTL_SRCS := $(PKG_SRCS) $(MOD_SRCS)

# O top de cada arquivo tem o mesmo nome do arquivo.
RTL_MODS := $(basename $(notdir $(MOD_SRCS)))

# Testbenches: tb/<módulo>_tb.sv, top <módulo>_tb. O selfcheck_fail_tb é
# tratado à parte (ele tem que falhar).
TB_SRCS := $(call declares,$(wildcard tb/*_tb.sv))
TESTS := $(filter-out selfcheck_fail,$(patsubst %_tb,%,$(basename $(notdir $(TB_SRCS)))))

# Designs da placa: fpga/<design>_top.sv, top <design>_top. Os outros .sv de
# fpga/ são módulos só de FPGA, usados por todos os designs (power-on reset).
FPGA_TOPS := $(call declares,$(wildcard fpga/*_top.sv))
FPGA_COMMON_SRCS := $(call declares,$(filter-out %_top.sv,$(wildcard fpga/*.sv)))
DESIGNS := $(patsubst %_top,%,$(basename $(notdir $(FPGA_TOPS))))

# ---------------------------------------------------------------------------
# Módulos na linha de comando: `make test counter`
# ---------------------------------------------------------------------------

# O make lê cada palavra da linha de comando como um alvo. Quando um dos VERBS
# aparece, as outras palavras que não são alvos deste Makefile são nomes de
# módulos: vão para MODULES e viram alvos que não fazem nada (no fim deste
# arquivo). Sem módulos, cada verbo age sobre todos. Para fpga, os nomes são
# designs (blink) em vez de módulos.
#   make test                    todos os testbenches, mais o selfcheck
#   make test counter            só tb/counter_tb.sv
#   make lint counter outro
#   make fpga blink              bitstream de fpga/blink_top.sv
VERBS := test waves lint synth fpga
TARGETS := help setup tools tools-prune selfcheck clean $(VERBS) \
    $(addsuffix -%,$(VERBS) check)

GIVEN_VERBS := $(filter $(VERBS),$(MAKECMDGOALS))
ifneq ($(GIVEN_VERBS),)
  MODULES := $(filter-out $(TARGETS),$(MAKECMDGOALS))
endif

# `make test waves counter` é ambíguo: qual verbo recebe o módulo?
ifneq ($(MODULES),)
  ifneq ($(words $(GIVEN_VERBS)),1)
    $(error Módulos só podem vir depois de um destes: $(VERBS). Recebi: $(GIVEN_VERBS))
  endif
endif

ifneq ($(filter waves,$(MAKECMDGOALS)),)
  ifeq ($(MODULES),)
    $(error Uso: make waves <módulo>. Testbenches encontrados: $(or $(TESTS),(nenhum)))
  endif
endif

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------

# --binary já implica --timing. -j 0 usa todos os núcleos para compilar.
VERILATOR_TB_FLAGS := --binary --assert --x-assign unique --x-initial unique \
    -Irtl -Irtl/pkg -j 0 --quiet

# Repassadas ao make que o Verilator chama para compilar o C++. LINK também
# precisa ser o mesmo compilador (senão a ligação usa o g++ do sistema).
# PYTHON3 é o da OSS CAD Suite, usado por um script interno do Verilator.
VERILATOR_MAKEFLAGS := -MAKEFLAGS "CXX=$(CXX)" -MAKEFLAGS "LINK=$(CXX)" \
    -MAKEFLAGS "PYTHON3=$(TOOLS_DIR)/bin/tabbypy3"

# O Verilator sempre liga com -latomic. No RHEL/Rocky 9 o pacote libatomic
# costuma faltar (instalar exige root) e a ligação falha. Em x86-64 as
# operações atômicas que o Verilator usa não precisam dessa biblioteca, então
# a tiramos nesse caso.
ifeq ($(shell echo 'int main(){}' | $(CXX) -x c++ - -o /dev/null -latomic 2>/dev/null && echo ok),)
  VERILATOR_MAKEFLAGS += -MAKEFLAGS "CFG_LDLIBS_THREADS=-pthread"
endif

# --trace-fst (make waves) inclui <lz4.h> e liga com -llz4. O RHEL/Rocky 9
# distribui o lz4.h num pacote separado (lz4-devel), que costuma faltar em
# máquinas sem root. Nesse caso o `make tools` compila uma cópia local em
# .tools/ e apontamos o compilador para ela.
LZ4_DIR := $(TOOLS_ROOT)/lz4-$(LZ4_VERSION)
ifeq ($(shell echo 'int main() { return LZ4_compressBound(1) > 0 ? 0 : 1; }' | $(CXX) -x c++ -include lz4.h - -o /dev/null -llz4 2>/dev/null && echo ok),)
  VERILATOR_FST_FLAGS := -CFLAGS -I$(LZ4_DIR)/include -LDFLAGS -L$(LZ4_DIR)/lib
endif

# ccache (opcional): se estiver instalado no host, acelera a recompilação do
# C++ gerado pelo Verilator. O cache fica em .tools/ccache, limitado a 1 GB; o
# ccache apaga as entradas mais antigas quando chega ao limite.
ifneq ($(shell command -v ccache 2>/dev/null),)
  VERILATOR_MAKEFLAGS += -MAKEFLAGS "OBJCACHE=ccache"
  export CCACHE_DIR := $(TOOLS_ROOT)/ccache
  export CCACHE_MAXSIZE := 1G
endif

# Placa: Digilent Nexys A7-100T, com uma Artix-7 XC7A100T, encapsulamento
# CSG324, speed grade -1. Os pinos estão em fpga/nexys-a7.xdc.
BOARD := Nexys A7-100T
FPGA_PART := xc7a100tcsg324-1
BOARD_XDC := fpga/nexys-a7.xdc
FPGA_BUILD := build/fpga

# --x-initial unique só sorteia os valores iniciais se pedirmos na execução.
# Isso ajuda a achar registradores que dependem de um valor de power-up.
SIM_ARGS = +verilator+seed+$(SEED) +verilator+rand+reset+2

# Abre a onda $(1) no $(VIEWER), em segundo plano, para o make voltar na hora.
# A saída do visualizador vai para $(2). Sem display (ssh, CI) só avisa.
define open_viewer
	@if [ -z "$(VIEWER)" ]; then :; \
	elif [ -z "$$DISPLAY$$WAYLAND_DISPLAY" ]; then \
	    echo "sem display: $(VIEWER) não foi aberto"; \
	else \
	    echo "abrindo $(1) no $(VIEWER) (log em $(2))"; \
	    nohup $(VIEWER) $(1) >$(2) 2>&1 & \
	fi
endef

# Compila tb/$(1)_tb.sv com todo o RTL em build/$(2)/. $(3) são flags extras.
define build_tb
	@mkdir -p build/$(2)
	verilator $(VERILATOR_TB_FLAGS) $(VERILATOR_MAKEFLAGS) $(3) \
	    --top-module $(1)_tb --Mdir build/$(2) -o $(1)_tb \
	    $(RTL_SRCS) tb/$(1)_tb.sv
endef

# Falha com uma mensagem clara se o testbench de $* ainda não existe.
define require_tb
	@if [ -z "$(filter tb/$*_tb.sv,$(TB_SRCS))" ]; then \
	    echo "ERRO: tb/$*_tb.sv não existe ou ainda não declara um módulo."; \
	    exit 1; \
	fi
endef

# O mesmo para o RTL de $*, usado por lint e synth.
define require_rtl
	@if [ -z "$(filter $*,$(RTL_MODS))" ]; then \
	    echo "ERRO: rtl/$*.sv não existe ou ainda não declara um módulo."; \
	    exit 1; \
	fi
endef

# O mesmo para o top da placa do design $*, usado por fpga.
define require_top
	@if [ -z "$(filter $*,$(DESIGNS))" ]; then \
	    echo "ERRO: fpga/$*_top.sv não existe ou ainda não declara um módulo."; \
	    exit 1; \
	fi
endef

# ---------------------------------------------------------------------------
# Alvos
# ---------------------------------------------------------------------------

.PHONY: help setup tools tools-prune check-tools check-slang check-vivado lint test selfcheck synth waves fpga clean

help:
	@echo "Alvos:"
	@echo "  make setup            setup completo: ferramentas, lint e testes"
	@echo "  make tools            instala as ferramentas do tools.lock em .tools/"
	@echo "  make tools-prune      apaga versões da OSS CAD Suite que não estão no tools.lock"
	@echo "  make lint [módulo]    lint do RTL (Verilator -Wall e sv-elab)"
	@echo "  make test             roda todos os testbenches (inclui o selfcheck)"
	@echo "  make test <módulo>    roda um testbench, ex.: make test counter"
	@echo "  make selfcheck        confirma que um assert que falha reprova o teste"
	@echo "  make synth [módulo]   verifica a síntese (Yosys, synth_xilinx)"
	@echo "  make waves <módulo>   roda um testbench, escreve build/<módulo>.fst e abre o Surfer"
	@echo "  make fpga [design]    bitstream de fpga/<design>_top.sv (Yosys + Vivado), com resumo"
	@echo "  make clean            apaga build/"
	@echo ""
	@echo "lint, test, synth, waves e fpga aceitam vários nomes: make test a b"
	@echo "Completar com TAB no bash e no fish: veja scripts/completion/."
	@echo ""
	@echo "Variáveis: SEED=$(SEED) CXX=$(CXX) VIEWER=$(VIEWER)"
	@echo "Placa:     $(BOARD) ($(FPGA_PART))"
	@echo "Vivado:    $(or $(VIVADO),(não encontrado; só o make fpga precisa dele))"
	@echo "Módulos encontrados:     $(or $(RTL_MODS),(nenhum))"
	@echo "Testbenches encontrados: $(or $(TESTS),(nenhum))"
	@echo "Designs encontrados:     $(or $(DESIGNS),(nenhum))"

tools:
	CXX="$(CXX)" bash scripts/setup-tools.sh

# Setup completo para começar a programar: instala as ferramentas e roda lint
# e testes uma vez, provando que o fluxo funciona nesta máquina. lint e test
# rodam num make novo porque a detecção do sv-elab (no início deste arquivo)
# acontece quando o Makefile é lido, antes de as ferramentas existirem.
setup: tools
	$(MAKE) lint test
	@echo ""
	@echo "Setup concluído. Próximos passos:"
	@echo "  - escreva o RTL em rtl/ e o testbench em tb/ (modelo: tb/counter_tb.sv)"
	@echo "  - make test <módulo>   roda um testbench"
	@echo "  - make waves <módulo>  escreve build/<módulo>.fst e abre no Surfer"
	@echo "  - make fpga blink      gera o bitstream do exemplo (precisa do Vivado)"
	@echo "  - make help            lista todos os alvos"

# Aceita KEEP="data1 data2" e YES=1 (pelo ambiente).
tools-prune:
	bash scripts/prune-tools.sh

check-tools:
	@if [ ! -d "$(TOOLS_DIR)" ]; then \
	    echo "ERRO: $(TOOLS_DIR) não existe. Rode \`make tools\`."; \
	    exit 1; \
	fi

check-slang: check-tools
	@if [ "$(SLANG_MODE)" != builtin ] && [ "$(SLANG_MODE)" != plugin ]; then \
	    echo "ERRO: o Yosys em $(TOOLS_DIR) não tem read_slang (sv-elab)."; \
	    exit 1; \
	fi

check-vivado:
	@if [ -z "$(VIVADO)" ] || [ ! -x "$(VIVADO)" ]; then \
	    echo "ERRO: Vivado não encontrado (o make fpga usa para place & route e bitstream)."; \
	    echo "Ponha o vivado no PATH ou indique onde está: make fpga VIVADO=/caminho/bin/vivado"; \
	    exit 1; \
	fi

# --- lint -------------------------------------------------------------------

lint: $(addprefix lint-,$(or $(MODULES),$(RTL_MODS)))

lint-%: check-slang
	$(require_rtl)
	verilator --lint-only -Wall --quiet -Irtl -Irtl/pkg --top-module $* $(RTL_SRCS)
	yosys -q $(SLANG_LOAD) -p "read_slang -DSYNTHESIS -I rtl -I rtl/pkg --top $* $(RTL_SRCS); hierarchy -check -top $*"
	@echo "lint $*: ok"

# --- testes -----------------------------------------------------------------

# Com módulos na linha de comando, só os testbenches deles rodam (sem selfcheck).
test: $(if $(MODULES),,selfcheck) $(addprefix test-,$(or $(MODULES),$(TESTS)))

test-%: check-tools
	$(require_tb)
	$(call build_tb,$*,$*)
	build/$*/$*_tb $(SIM_ARGS)

# selfcheck_fail_tb tem um assert que falha de propósito. Este alvo só passa
# se o binário compila e depois sai com código diferente de zero.
selfcheck: check-tools
	$(call build_tb,selfcheck_fail,selfcheck_fail)
	@if build/selfcheck_fail/selfcheck_fail_tb $(SIM_ARGS) >build/selfcheck_fail/run.log 2>&1; then \
	    cat build/selfcheck_fail/run.log; \
	    echo "selfcheck: ERRO: selfcheck_fail_tb passou, mas devia falhar."; \
	    exit 1; \
	else \
	    echo "selfcheck: ok (selfcheck_fail_tb falhou com código $$?, como esperado)"; \
	fi

waves: $(addprefix waves-,$(MODULES))

# Por padrão o Verilator deixa fora do dump qualquer array desempacotado com
# mais de 32 elementos (memórias, banco de registradores). --trace-max-array
# aumenta esse limite.
waves-%: check-tools
	$(require_tb)
	$(call build_tb,$*,$*-waves,--trace-fst --trace-max-array 1024 $(VERILATOR_FST_FLAGS))
	build/$*-waves/$*_tb $(SIM_ARGS) +dumpfile=build/$*.fst
	@echo "ondas em build/$*.fst"
	$(call open_viewer,build/$*.fst,build/$*-waves/viewer.log)

# --- síntese ----------------------------------------------------------------

synth: $(addprefix synth-,$(or $(MODULES),$(RTL_MODS)))

# Síntese do módulo sozinho, sem buffers de I/O e de clock (que só fazem
# sentido no top da placa), para a contagem de recursos refletir só a lógica.
synth-%: check-slang
	$(require_rtl)
	@mkdir -p build/synth
	yosys -q $(SLANG_LOAD) -l build/synth/$*.log \
	    -p "read_slang -DSYNTHESIS -I rtl -I rtl/pkg --top $* $(RTL_SRCS); synth_xilinx -family xc7 -noiopad -noclkbuf -top $*; tee -o build/synth/$*.stat stat"
	@echo "synth $*: ok (sv-elab $(SLANG_MODE); relatório em build/synth/$*.stat)"

# --- FPGA -------------------------------------------------------------------

fpga: $(addprefix fpga-,$(or $(MODULES),$(DESIGNS)))

# Síntese no Yosys (netlist EDIF), place & route e bitstream no Vivado
# (scripts/vivado-impl.tcl). O Vivado acha o top pelo nome do arquivo do
# netlist, daí <design>_top.edf. O resumo (scripts/fpga-summary.sh) aparece
# mesmo quando o timing falha; nesse caso o bitstream não é gerado. Os
# resultados da rodada anterior são apagados antes, para o resumo nunca
# mostrar dados velhos.
fpga-%: check-slang check-vivado
	$(require_top)
	@mkdir -p $(FPGA_BUILD)
	yosys -q $(SLANG_LOAD) -l $(FPGA_BUILD)/$*-synth.log \
	    -p "read_slang -DSYNTHESIS -I rtl -I rtl/pkg --top $*_top $(RTL_SRCS) $(FPGA_COMMON_SRCS) fpga/$*_top.sv; synth_xilinx -family xc7 -flatten -top $*_top -edif $(FPGA_BUILD)/$*_top.edf"
	@rm -f $(addprefix $(FPGA_BUILD)/$*,.bit -clocks.txt -util.rpt -timing.rpt -vivado.log)
	@echo "vivado: place & route e bitstream de $*_top (log em $(FPGA_BUILD)/$*-vivado.log)"
	@cd $(FPGA_BUILD) && \
	    "$(VIVADO)" -mode batch -nojournal -notrace -log $*-vivado.log \
	        -source $(CURDIR)/scripts/vivado-impl.tcl \
	        -tclargs $* $*_top.edf $(CURDIR)/$(BOARD_XDC) $(FPGA_PART) >/dev/null; \
	    status=$$?; \
	    bash $(CURDIR)/scripts/fpga-summary.sh $* "$* na $(BOARD)" || status=1; \
	    exit $$status
	@echo "fpga $*: ok (bitstream em $(FPGA_BUILD)/$*.bit)"

clean:
	rm -rf build

# Os nomes de módulos dados na linha de comando (veja MODULES) também são
# alvos. Esta regra faz com que não façam nada; o trabalho é do verbo que veio
# junto com eles.
ifneq ($(MODULES),)
.PHONY: $(MODULES)
$(MODULES):
	@:
endif

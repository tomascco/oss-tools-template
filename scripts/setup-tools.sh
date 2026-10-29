#!/usr/bin/env bash
#
# Instala a OSS CAD Suite fixada no tools.lock, sem root.
#
# Uso (normalmente pelo `make tools`):
#   scripts/setup-tools.sh
#
# Variáveis de ambiente opcionais:
#   TOOLS_ROOT  diretório onde ficam as versões (padrão: .tools/ dentro do
#               repositório, ignorado pelo git)
#   CXX         compilador C++ usado pelo Verilator (padrão: g++)
#   TGZ         caminho de um .tgz já baixado (instalação offline)
#
# A instalação é atômica: tudo acontece num diretório temporário dentro de
# TOOLS_ROOT, e só no fim ele é renomeado para oss-cad-suite-<data>. Se o
# script for interrompido, o diretório final nunca fica pela metade.
#
# Nada persistente é escrito fora de TOOLS_ROOT. Para remover tudo, basta
# apagar o diretório .tools/.
#
# Versões antigas não são apagadas aqui. Use `make tools-prune`.
#
# O Vivado (usado só pelo `make fpga`) não é instalado por este script.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../tools.lock
source "$REPO_ROOT/tools.lock"

TOOLS_ROOT="${TOOLS_ROOT:-$REPO_ROOT/.tools}"
CXX="${CXX:-g++}"
TGZ="${TGZ:-}"

DATE="$OSS_CAD_SUITE_DATE"
EXPECTED_SHA256="$OSS_CAD_SUITE_SHA256"
TGZ_NAME="oss-cad-suite-linux-x64-${DATE//-/}.tgz"
URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${DATE}/${TGZ_NAME}"
FINAL_DIR="$TOOLS_ROOT/oss-cad-suite-$DATE"

# Mínimos. Verilator: covergroups (5.050) e UVM 2020-3.2 (5.052).
# Compilador: --timing (ativado por --binary) usa corrotinas do C++20; a
# documentação do Verilator pede "GCC 10, Clang 5, or newer".
MIN_VERILATOR=5.052
MIN_GCC=10
MIN_CLANG=5

info() { echo "[setup-tools] $*"; }
die() {
    echo "[setup-tools] ERRO: $*" >&2
    exit 1
}

# Retorna sucesso se a versão $1 >= $2 (comparação no estilo 5.052 >= 5.050).
version_ge() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

# ---------------------------------------------------------------------------
# Pré-requisitos do host
# ---------------------------------------------------------------------------

print_compiler_help() {
    cat >&2 <<EOF

O Verilator precisa de um compilador C++ com corrotinas:
GCC $MIN_GCC ou mais novo, ou Clang $MIN_CLANG ou mais novo.
(O Rocky Linux 8 traz o GCC 8; o Rocky Linux 9 traz o GCC 11.)

Alternativas sem root:

  1) Um gcc-toolset já instalado pelo administrador:
EOF
    local found=0 gxx
    for gxx in /opt/rh/gcc-toolset-*/root/usr/bin/g++; do
        if [ -x "$gxx" ]; then
            echo "       encontrado: $gxx" >&2
            found=1
        fi
    done
    if [ "$found" = 0 ]; then
        echo "       (nenhum encontrado em /opt/rh/gcc-toolset-*)" >&2
    fi
    cat >&2 <<EOF
     Use assim (em todo comando make):
       CXX=/opt/rh/gcc-toolset-N/root/usr/bin/g++ make tools
       CXX=/opt/rh/gcc-toolset-N/root/usr/bin/g++ make test

  2) micromamba com gxx e make do conda-forge, dentro do .tools/ do repositório:
       cd $REPO_ROOT
       mkdir -p .tools/micromamba
       curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xj -C .tools/micromamba bin/micromamba
       .tools/micromamba/bin/micromamba create -y -r .tools/micromamba -p .tools/cxx -c conda-forge gxx make
     Depois:
       CXX=$REPO_ROOT/.tools/cxx/bin/g++ .tools/cxx/bin/make tools
       CXX=$REPO_ROOT/.tools/cxx/bin/g++ .tools/cxx/bin/make test

EOF
}

check_host() {
    command -v make >/dev/null 2>&1 ||
        { print_compiler_help; die "'make' não encontrado no PATH."; }
    # O executável `verilator` é um script Perl.
    command -v perl >/dev/null 2>&1 ||
        die "'perl' não encontrado no PATH (o Verilator precisa dele)."
    # O RHEL/Rocky 9 distribui o FindBin num pacote separado (perl-FindBin).
    # Sem ele, usa o substituto de scripts/perl5/ (o Makefile faz o mesmo).
    if ! perl -MFindBin -e1 2>/dev/null; then
        export PERL5LIB="$REPO_ROOT/scripts/perl5${PERL5LIB:+:$PERL5LIB}"
        info "perl:      sem FindBin; usando scripts/perl5/FindBin.pm"
    fi
    command -v sha256sum >/dev/null 2>&1 ||
        die "'sha256sum' não encontrado no PATH."

    if ! command -v "$CXX" >/dev/null 2>&1; then
        print_compiler_help
        die "compilador '$CXX' não encontrado (defina CXX=...)."
    fi

    # Pergunta ao próprio compilador o que ele é. O Clang também define
    # __GNUC__, então ele é testado primeiro.
    local macros major
    macros="$(echo | "$CXX" -dM -E -x c++ - 2>/dev/null)" ||
        die "não foi possível executar '$CXX'."
    if major="$(echo "$macros" | awk '$2 == "__clang_major__" { print $3 }')" && [ -n "$major" ]; then
        if [ "$major" -lt "$MIN_CLANG" ]; then
            print_compiler_help
            die "'$CXX' é Clang $major; é preciso Clang $MIN_CLANG ou mais novo."
        fi
        info "compilador: $CXX (Clang $major)"
    elif major="$(echo "$macros" | awk '$2 == "__GNUC__" { print $3 }')" && [ -n "$major" ]; then
        if [ "$major" -lt "$MIN_GCC" ]; then
            print_compiler_help
            die "'$CXX' é GCC $major; é preciso GCC $MIN_GCC ou mais novo."
        fi
        info "compilador: $CXX (GCC $major)"
    else
        print_compiler_help
        die "não reconheci o compilador '$CXX'."
    fi
}

# ---------------------------------------------------------------------------
# Verificação de uma instalação (final, ou ainda no diretório temporário)
# ---------------------------------------------------------------------------

check_tools() {
    local dir="$1" v

    [ -x "$dir/bin/verilator" ] || die "$dir/bin/verilator não existe."
    [ -x "$dir/bin/yosys" ] || die "$dir/bin/yosys não existe."
    [ -x "$dir/bin/z3" ] || die "$dir/bin/z3 não existe (o Verilator usa no randomize())."

    v="$("$dir/bin/verilator" --version | awk '{ print $2 }')"
    version_ge "$v" "$MIN_VERILATOR" ||
        die "Verilator $v é velho demais; é preciso $MIN_VERILATOR ou mais novo."
    info "verilator: $("$dir/bin/verilator" --version)"

    info "yosys:     $("$dir/bin/yosys" --version)"
    info "z3:        $("$dir/bin/z3" --version)"
    # A saída vai para uma variável antes do grep: com pipefail, o `grep -q`
    # fecha o pipe cedo e o yosys morreria de SIGPIPE, parecendo uma falha.
    local help_out
    help_out="$("$dir/bin/yosys" -p "help read_slang" 2>&1 || true)"
    if grep -q "^ *read_slang \\[" <<<"$help_out"; then
        info "sv-elab:   read_slang embutido no Yosys"
        return
    fi
    help_out="$("$dir/bin/yosys" -m slang -p "help read_slang" 2>&1 || true)"
    if grep -q "^ *read_slang \\[" <<<"$help_out"; then
        info "sv-elab:   read_slang como plugin (yosys -m slang)"
        return
    fi
    die "o Yosys desta release não tem read_slang (sv-elab)."
}

# O wrapper bin/surfer de algumas releases (2026-10-20, pelo menos) tem duas
# linhas exec: primeiro uma com a glibc do host, depois uma com a glibc que
# vem em lib/. Só a primeira roda, então em hosts com glibc mais velha (o
# Rocky 9 tem a 2.34) o Surfer falha com "GLIBC_2.43 not found". Apagamos a
# primeira linha para que a glibc empacotada seja usada.
#
# Com a glibc empacotada, o Surfer só acha as bibliotecas de lib/. lib/ tem o
# driver Mesa para GLX (X11), mas não o de EGL (Wayland), então numa sessão
# Wayland o Surfer entra em pânico com "provided display handle is not
# supported". Quando o X11 também está disponível (XWayland, DISPLAY
# definido), tiramos WAYLAND_DISPLAY para o Surfer abrir por X11 e GLX.
#
# Cada passo não faz nada se o wrapper já estiver corrigido.
fix_surfer_wrapper() {
    local wrapper="$1/bin/surfer"
    [ -f "$wrapper" ] || return 0
    grep -q '^exec .*/lib/ld-linux-x86-64.so.2 .*/libexec/surfer' "$wrapper" || return 0
    if grep -q '^exec "$release_topdir_abs"/libexec/surfer ' "$wrapper"; then
        sed -i '\|^exec "$release_topdir_abs"/libexec/surfer |d' "$wrapper"
        info "surfer:    wrapper corrigido para usar a glibc empacotada"
    fi
    if ! grep -q 'unset WAYLAND_DISPLAY' "$wrapper"; then
        sed -i '\|^exec .*/lib/ld-linux-x86-64.so.2 |i [ -n "$DISPLAY" ] \&\& unset WAYLAND_DISPLAY' "$wrapper"
        info "surfer:    wrapper corrigido para usar X11 (não há driver EGL no pacote)"
    fi
}

# Compila e roda um testbench mínimo com --binary, usando $CXX. Isso prova que
# compilador, make, perl, corrotinas (--timing) e z3 (randomize com
# constraint) funcionam juntos nesta máquina. Roda dentro do diretório
# temporário da instalação, que o trap apaga no fim.
smoke_test() {
    local dir="$1" work="$TMP_DIR/smoke"
    mkdir -p "$work"
    cat >"$work/smoke_tb.sv" <<'EOF'
class smoke_txn;
    rand bit [7:0] x;
    constraint c_x { x > 8'd10; x < 8'd20; }
endclass

module smoke_tb;
    smoke_txn t;
    initial begin
        t = new();
        #1;
        if (t.randomize() == 0 || t.x <= 10 || t.x >= 20) $fatal(1, "randomize failed");
        $display("PASS");
        $finish;
    end
endmodule
EOF
    # O Verilator sempre liga com -latomic. Sem o pacote libatomic
    # (RHEL/Rocky 9, sem root) tiramos a flag; x86-64 não precisa dela (o
    # Makefile faz o mesmo).
    local makeflags=(-MAKEFLAGS "CXX=$CXX" -MAKEFLAGS "LINK=$CXX"
        -MAKEFLAGS "PYTHON3=$dir/bin/tabbypy3")
    if ! echo 'int main(){}' | "$CXX" -x c++ - -o /dev/null -latomic 2>/dev/null; then
        makeflags+=(-MAKEFLAGS "CFG_LDLIBS_THREADS=-pthread")
        info "sem libatomic; ligando sem -latomic"
    fi
    info "testando o Verilator com '$CXX' (leva alguns segundos)..."
    if ! (
        cd "$work" &&
            PATH="$dir/bin:$PATH" verilator --binary -j 0 --top-module smoke_tb \
                "${makeflags[@]}" smoke_tb.sv >build.log 2>&1 &&
            PATH="$dir/bin:$PATH" ./obj_dir/Vsmoke_tb >run.log 2>&1 &&
            grep -q PASS run.log
    ); then
        tail -n 20 "$work"/build.log "$work"/run.log >&2 || true
        print_compiler_help
        die "o Verilator não conseguiu compilar e rodar um teste com '$CXX'."
    fi
    info "teste do Verilator: ok"
}

# ---------------------------------------------------------------------------
# lz4 para --trace-fst (só em hosts sem ele)
# ---------------------------------------------------------------------------

# Baixa um arquivo com curl ou wget. $1 = URL, $2 = destino.
download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --progress-bar -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$2" "$1"
    else
        return 1
    fi
}

# O escritor de FST do Verilator 5.053+ inclui <lz4.h> e liga com -llz4. O
# RHEL/Rocky 9 distribui o lz4.h num pacote separado (lz4-devel), que costuma
# faltar em máquinas sem root. Nesse caso compilamos a liblz4.a a partir do
# fonte fixado em .tools/lz4-<versão>/ (o Makefile a usa do mesmo jeito). Só
# o lz4.c é necessário, e ele compila como C++, então $CXX basta.
install_lz4() {
    local dir="$TOOLS_ROOT/lz4-$LZ4_VERSION"
    if echo 'int main() { return LZ4_compressBound(1) > 0 ? 0 : 1; }' |
        "$CXX" -x c++ -include lz4.h - -o /dev/null -llz4 2>/dev/null; then
        info "lz4:       encontrado no host"
        return
    fi
    if [ -f "$dir/lib/liblz4.a" ]; then
        info "lz4:       não está no host; usando $dir"
        return
    fi

    # Mesmo esquema atômico da OSS CAD Suite: compila num diretório
    # temporário e renomeia no fim. LZ4_TMP é global para o trap de EXIT vê-lo.
    local tmp name="lz4-$LZ4_VERSION.tar.gz" actual
    mkdir -p "$TOOLS_ROOT"
    LZ4_TMP="$(mktemp -d "$TOOLS_ROOT/.lz4-$LZ4_VERSION.tmp.XXXXXX")"
    tmp="$LZ4_TMP"
    trap 'rm -rf -- "$LZ4_TMP"' EXIT

    info "lz4:       não está no host; compilando a $LZ4_VERSION em $dir"
    download "https://github.com/lz4/lz4/releases/download/v$LZ4_VERSION/$name" "$tmp/$name" ||
        die "falha ao baixar o lz4."
    actual="$(sha256sum "$tmp/$name" | awk '{ print $1 }')"
    [ "$actual" = "$LZ4_SHA256" ] ||
        die "SHA-256 do lz4 não confere.
  esperado (tools.lock): $LZ4_SHA256
  obtido:                $actual"
    tar -xzf "$tmp/$name" -C "$tmp"

    local src="$tmp/lz4-$LZ4_VERSION/lib"
    mkdir -p "$tmp/out/include" "$tmp/out/lib"
    "$CXX" -O2 -fPIC -c "$src/lz4.c" -o "$tmp/lz4.o" || die "não foi possível compilar o lz4.c."
    ar rcs "$tmp/out/lib/liblz4.a" "$tmp/lz4.o"
    cp "$src/lz4.h" "$tmp/out/include/"
    cp "$tmp/lz4-$LZ4_VERSION/LICENSE" "$tmp/out/"
    mv -T -- "$tmp/out" "$dir"
    rm -rf -- "$tmp"
    trap - EXIT
}

# ---------------------------------------------------------------------------
# Programa principal
# ---------------------------------------------------------------------------

check_host
install_lz4

if [ -d "$FINAL_DIR" ]; then
    info "OSS CAD Suite $DATE já instalada em $FINAL_DIR"
    check_tools "$FINAL_DIR"
    fix_surfer_wrapper "$FINAL_DIR"
    exit 0
fi

mkdir -p "$TOOLS_ROOT"

# Diretório temporário com prefixo fixo, que o `make tools-prune` reconhece
# caso uma instalação seja interrompida de um jeito que impeça o trap de rodar.
TMP_DIR="$(mktemp -d "$TOOLS_ROOT/.oss-cad-suite-$DATE.tmp.XXXXXX")"
cleanup() { rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT
trap 'echo; die "interrompido; nada foi instalado."' INT TERM

if [ -n "$TGZ" ]; then
    [ -f "$TGZ" ] || die "TGZ=$TGZ não existe."
    info "usando o arquivo local $TGZ"
    tgz_file="$TGZ"
else
    tgz_file="$TMP_DIR/$TGZ_NAME"
    info "baixando $URL"
    download "$URL" "$tgz_file" ||
        die "falha no download (ou não há curl nem wget). Sem acesso ao GitHub? Baixe em outra máquina e use TGZ=/caminho/$TGZ_NAME"
fi

info "conferindo o SHA-256..."
actual_sha256="$(sha256sum "$tgz_file" | awk '{ print $1 }')"
if [ "$actual_sha256" != "$EXPECTED_SHA256" ]; then
    die "SHA-256 não confere.
  esperado (tools.lock): $EXPECTED_SHA256
  obtido:                $actual_sha256"
fi

info "extraindo..."
tar -xzf "$tgz_file" -C "$TMP_DIR"
# Apaga o .tgz baixado (um arquivo passado por TGZ= é do usuário e fica).
if [ -z "$TGZ" ]; then
    rm -f -- "$tgz_file"
fi

check_tools "$TMP_DIR/oss-cad-suite"
smoke_test "$TMP_DIR/oss-cad-suite"
fix_surfer_wrapper "$TMP_DIR/oss-cad-suite"

# Só agora o diretório recebe o nome final. Um rename dentro do mesmo sistema
# de arquivos é atômico.
mv -T -- "$TMP_DIR/oss-cad-suite" "$FINAL_DIR"
info "instalada em $FINAL_DIR"

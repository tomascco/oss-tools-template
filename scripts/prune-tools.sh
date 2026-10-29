#!/usr/bin/env bash
#
# Apaga, depois de confirmar, as versões da OSS CAD Suite diferentes da do tools.lock.
#
# Uso (normalmente pelo `make tools-prune`):
#   scripts/prune-tools.sh
#
# Variáveis de ambiente opcionais:
#   TOOLS_ROOT  diretório das instalações (padrão: .tools/ dentro do repositório)
#   KEEP        datas extras a manter, ex.: KEEP="2026-07-11 2026-04-02"
#   YES=1       não pede confirmação
#
# Só considera diretórios com nome exatamente oss-cad-suite-AAAA-MM-DD e os
# temporários deixados por instalações interrompidas
# (.oss-cad-suite-AAAA-MM-DD.tmp.*). Nada mais em TOOLS_ROOT é tocado.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../tools.lock
source "$REPO_ROOT/tools.lock"

TOOLS_ROOT="${TOOLS_ROOT:-$REPO_ROOT/.tools}"
KEEP="${KEEP:-}"
YES="${YES:-}"

DATE_RE='[0-9]{4}-[0-9]{2}-[0-9]{2}'

info() { echo "[tools-prune] $*"; }
die() {
    echo "[tools-prune] ERRO: $*" >&2
    exit 1
}

[ -d "$TOOLS_ROOT" ] || { info "$TOOLS_ROOT não existe; nada a fazer."; exit 0; }

for d in $KEEP; do
    [[ "$d" =~ ^$DATE_RE$ ]] || die "KEEP contém '$d', que não é uma data AAAA-MM-DD."
done

# Monta a lista do que pode ser apagado.
victims=()
for path in "$TOOLS_ROOT"/oss-cad-suite-* "$TOOLS_ROOT"/.oss-cad-suite-*; do
    [ -d "$path" ] || continue # também pula o padrão literal quando nada casa
    [ -L "$path" ] && continue # links simbólicos não são instalações nossas
    name="$(basename "$path")"

    if [[ "$name" =~ ^oss-cad-suite-($DATE_RE)$ ]]; then
        date="${BASH_REMATCH[1]}"
        [ "$date" = "$OSS_CAD_SUITE_DATE" ] && continue
        [[ " $KEEP " == *" $date "* ]] && continue
        victims+=("$path")
    elif [[ "$name" =~ ^\.oss-cad-suite-$DATE_RE\.tmp\.[A-Za-z0-9]+$ ]]; then
        victims+=("$path") # instalação interrompida
    fi
done

if [ "${#victims[@]}" -eq 0 ]; then
    info "nada a apagar (fixada: $OSS_CAD_SUITE_DATE${KEEP:+; mantidas: $KEEP})."
    exit 0
fi

info "versão fixada no tools.lock: $OSS_CAD_SUITE_DATE${KEEP:+ (também mantidas: $KEEP)}"
info "serão apagados:"
du -sh -- "${victims[@]}"

if [ "$YES" != 1 ]; then
    read -r -p "Apagar? [s/N] " answer
    case "$answer" in
    s | S | y | Y) ;;
    *)
        info "cancelado."
        exit 0
        ;;
    esac
fi

for path in "${victims[@]}"; do
    rm -rf -- "$path"
    info "apagado: $path"
done

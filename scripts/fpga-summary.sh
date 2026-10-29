#!/usr/bin/env bash
# Imprime os principais resultados de um `make fpga`: a frequência máxima de
# cada clock e quanto do chip o design usa. Lê os arquivos que o
# scripts/vivado-impl.tcl escreve no diretório atual.
#
#   scripts/fpga-summary.sh <design> <título>
#
# Sai com código 1 se algum clock não atinge a frequência pedida, ou se o
# Vivado parou antes de medir o timing.

set -euo pipefail

design=$1
title=$2

echo ""
echo "==== $title ===="

# Uma linha por clock: nome, período (ns), pior folga de setup (ns) ou "none"
# (clock sem nenhum caminho temporizado).
#   sys_clk 10.000 6.312
# Frequência máxima = 1 / (período - folga).
timing_ok=1
if [ -f "$design-clocks.txt" ]; then
    awk '
        BEGIN { print "Clocks (frequência máxima, veredito no alvo):" }
        {
            target = 1000 / $2
            if ($3 == "none") {
                printf "  %-12s sem caminhos temporizados (alvo %.2f MHz)\n", $1, target
                next
            }
            fmax = 1000 / ($2 - $3)
            verdict = ($3 < 0) ? "FAIL" : "PASS"
            if ($3 < 0) fail = 1
            printf "  %-12s %.2f MHz (%s em %.2f MHz, folga %s ns)\n", $1, fmax, verdict, target, $3
        }
        END {
            if (NR == 0) print "  (nenhum clock com restrição de timing)"
            exit fail
        }
    ' "$design-clocks.txt" || timing_ok=0
else
    timing_ok=0
fi

# Tabelas do report_utilization; só os recursos que mais importam.
#   | Slice LUTs              |    4 |     0 |          0 |     63400 | <0.01 |
if [ -f "$design-util.rpt" ]; then
    awk -F'|' '
        BEGIN {
            label["Slice LUTs"]      = "Lógica (LUT6)"
            label["Slice Registers"] = "Flip-flops"
            label["Block RAM Tile"]  = "Block RAM (36 Kbit)"
            label["DSPs"]            = "DSP48E1"
            label["Bonded IOB"]      = "Pinos de I/O"
            label["BUFGCTRL"]        = "Buffers de clock"
            label["MMCME2_ADV"]      = "MMCM"
            label["PLLE2_ADV"]       = "PLL"
            n = split("Slice LUTs|Slice Registers|Block RAM Tile|DSPs|Bonded IOB|BUFGCTRL|MMCME2_ADV|PLLE2_ADV", keys, "|")
        }
        NF >= 7 {
            key = $2; gsub(/^ +| +$/, "", key)
            if ((key in label) && !(key in used)) {
                used[key] = $3; avail[key] = $(NF - 2); pct[key] = $(NF - 1)
                gsub(/ /, "", used[key]); gsub(/ /, "", avail[key]); gsub(/ /, "", pct[key])
            }
        }
        END {
            print "Utilização:"
            for (i = 1; i <= n; i++) {
                k = keys[i]
                if (k in used) printf "  %-20s %6s / %-6s %5s%%\n", label[k], used[k], avail[k], pct[k]
            }
        }
    ' "$design-util.rpt"
fi

# Erros do Vivado, se houver. As mensagens de DRC são longas: fica só a
# primeira frase e a lista de portas com problema.
#   ERROR: [DRC UCIO-1] Unconstrained Logical Port: 1 out of 2 logical ports
#   have no user assigned ... Problem ports: leds.
if [ -f "$design-vivado.log" ] && grep -q '^ERROR' "$design-vivado.log"; then
    echo "Erros do Vivado:"
    grep '^ERROR' "$design-vivado.log" | awk '{
        msg = $0; ports = ""
        if (match(msg, /Problem ports: [^.]*\./)) ports = " " substr(msg, RSTART, RLENGTH)
        sub(/\. .*/, ".", msg)
        print "  " msg ports
    }'
    if grep -q '^ERROR: \[DRC \(UCIO\|NSTD\)-1\]' "$design-vivado.log"; then
        echo "  Dica: toda porta do top precisa ter o mesmo nome de uma porta do"
        echo "  fpga/nexys-a7.xdc (ex.: led[0], sw[3], btnc)."
    fi
fi

echo "Log completo: $(pwd)/$design-vivado.log"

if [ ! -f "$design-clocks.txt" ]; then
    echo ""
    echo "ERRO: o Vivado parou antes da análise de timing (veja os erros acima)."
    exit 1
fi
if [ "$timing_ok" = 0 ]; then
    echo ""
    echo "ERRO: um clock não atinge a frequência pedida (FAIL acima); bitstream não gerado."
    exit 1
fi

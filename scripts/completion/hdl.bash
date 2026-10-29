# Completar com TAB no bash para o Makefile do template HDL: `make test <TAB>`
# lista os testbenches, `make lint <TAB>` os módulos do RTL, `make fpga <TAB>`
# os designs da placa.
#
# Para ativar, adicione esta linha ao ~/.bashrc (depois do bash-completion):
#   source /caminho/do/repositorio/scripts/completion/hdl.bash
#
# Dentro de um clone do template, completa alvos e nomes de módulos lendo
# rtl/, tb/ e fpga/ diretamente (rápido: o make não é executado). Em qualquer
# outro lugar, o `make` mantém a completação de sempre do bash-completion.

# Mesma regra do Makefile: só contam os arquivos que já declaram um módulo.
_hdl_declared() {
    grep -lE '^[[:space:]]*module[[:space:]]' "$@" 2>/dev/null
}

_hdl_make() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}

    # Opções (-j) e variáveis (SEED=2) vão para a completação normal do make.
    if [[ $cur == -* || $cur == *=* || $prev == = ]] ||
        ! head -n 1 Makefile 2>/dev/null | grep -q '^# Makefile do template HDL'; then
        [[ -n $_hdl_make_orig ]] && "$_hdl_make_orig" "$@"
        return
    fi

    # O último verbo da linha decide o que vem depois.
    local word verb=
    for word in "${COMP_WORDS[@]:1:COMP_CWORD-1}"; do
        case $word in test | waves | lint | synth | fpga) verb=$word ;; esac
    done

    local candidates f
    case $verb in
    test | waves)
        for f in $(_hdl_declared tb/*_tb.sv); do
            f=${f#tb/}
            f=${f%_tb.sv}
            [[ $f != selfcheck_fail ]] && candidates+=" $f"
        done
        ;;
    lint | synth)
        for f in $(_hdl_declared rtl/*.sv); do
            f=${f#rtl/}
            candidates+=" ${f%.sv}"
        done
        ;;
    fpga)
        for f in $(_hdl_declared fpga/*_top.sv); do
            f=${f##*/}
            candidates+=" ${f%_top.sv}"
        done
        ;;
    *)
        # Manter em sincronia com o `make help`.
        candidates="help setup tools tools-prune lint test selfcheck synth waves fpga clean"
        ;;
    esac

    COMPREPLY=($(compgen -W "$candidates" -- "$cur"))
}

# Carrega agora a completação de make do próprio bash-completion (normalmente
# ela só carrega no primeiro uso), para o _hdl_make poder recorrer a ela fora
# deste repositório.
_comp_load make 2>/dev/null || __load_completion make 2>/dev/null
_hdl_spec=$(complete -p make 2>/dev/null)
if [[ $_hdl_spec =~ -F\ ([^ ]+) && ${BASH_REMATCH[1]} != _hdl_make ]]; then
    _hdl_make_orig=${BASH_REMATCH[1]}
fi
unset _hdl_spec
complete -F _hdl_make make

# Completar com TAB no fish para o Makefile do template HDL: `make test <TAB>`
# lista os testbenches, `make lint <TAB>` os módulos do RTL, `make fpga <TAB>`
# os designs da placa.
#
# Para ativar, adicione esta linha ao ~/.config/fish/config.fish:
#   set -p fish_complete_path /caminho/do/repositorio/scripts/completion
#
# O fish passa a carregar este arquivo no lugar do make.fish dele. Este
# arquivo carrega primeiro o make.fish do fish e só muda como os alvos são
# listados: dentro de um clone do template, eles são lidos de rtl/, tb/ e
# fpga/ diretamente (rápido: o make não é executado). Em qualquer outro lugar,
# o `make` mantém a completação de sempre.

# Completação de make do próprio fish: embutida no binário desde o fish 4, um
# arquivo em $__fish_data_dir antes disso.
if status get-file completions/make.fish &>/dev/null
    status get-file completions/make.fish | source
else if test -f $__fish_data_dir/completions/make.fish
    source $__fish_data_dir/completions/make.fish
end

# Guarda o listador de alvos do fish com outro nome, para usá-lo fora do template.
if functions -q __fish_complete_make_targets
    functions -c __fish_complete_make_targets __hdl_fish_make_targets
end

# Mesma regra do Makefile: só contam os arquivos que já declaram um módulo.
function __hdl_declared
    grep -lE '^[[:space:]]*module[[:space:]]' $argv 2>/dev/null
end

# Chamada pela completação de make do fish com a linha de comando inteira.
function __fish_complete_make_targets
    if not string match -q '# Makefile do template HDL*' -- (head -n 1 Makefile 2>/dev/null)
        functions -q __hdl_fish_make_targets
        and __hdl_fish_make_targets $argv
        return
    end

    # O último verbo antes da palavra sendo completada decide o que vem depois.
    set -l words (commandline -opc)
    set -l verb
    for word in $words[2..]
        if contains -- $word test waves lint synth fpga
            set verb $word
        end
    end

    switch "$verb"
        case test waves
            __hdl_declared tb/*_tb.sv | string replace -r '^tb/(.*)_tb\.sv$' '$1' |
                string match -v selfcheck_fail | string replace -r '$' \ttestbench
        case lint synth
            __hdl_declared rtl/*.sv | string replace -r '^rtl/(.*)\.sv$' '$1\tmódulo'
        case fpga
            __hdl_declared fpga/*_top.sv |
                string replace -r '^fpga/(.*)_top\.sv$' '$1\tdesign'
        case '*'
            # Manter em sincronia com o `make help`.
            printf '%s\n' \
                help\t'lista os alvos' \
                setup\t'ferramentas, lint e testes' \
                tools\t'instala as ferramentas do tools.lock' \
                tools-prune\t'apaga versões antigas da OSS CAD Suite' \
                lint\t'lint do RTL [módulo]' \
                test\t'roda os testbenches [módulo]' \
                selfcheck\t'um assert que falha tem que reprovar' \
                synth\t'verifica a síntese [módulo]' \
                waves\t'escreve build/<módulo>.fst e abre o Surfer' \
                fpga\t'gera o bitstream [design]' \
                clean\t'apaga build/'
    end
end

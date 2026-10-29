# Substituto mínimo do módulo FindBin, que faz parte do núcleo do Perl.
#
# Por que existe: o executável `verilator` é um script Perl que começa com
# `use FindBin`. O FindBin vem com o Perl, mas o RHEL/Rocky/Alma 9 o separam
# num pacote próprio (perl-FindBin), que costuma faltar, e instalar exige
# root. Este arquivo cobre só o que o Verilator usa.
#
# Só é usado como reserva: o Makefile e o scripts/setup-tools.sh põem este
# diretório no PERL5LIB apenas quando `perl -MFindBin -e1` falha. Hosts que
# têm o módulo de verdade continuam usando o deles.
#
# Variáveis exportadas (mesmo significado do FindBin original):
#   $Bin, $Script          diretório e nome do script, como foi chamado
#   $RealBin, $RealScript  o mesmo, depois de resolver links simbólicos
#   $Dir, $RealDir         apelidos de $Bin e $RealBin

package FindBin;

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Basename qw(basename dirname);
use File::Spec;
use Exporter qw(import);

our $VERSION = '1.51';
our @EXPORT_OK = qw($Bin $Script $RealBin $RealScript $Dir $RealDir);
our %EXPORT_TAGS = (ALL => [@EXPORT_OK]);
our ($Bin, $Script, $RealBin, $RealScript, $Dir, $RealDir);

sub init {
    my $script = $0;

    # `perl -e '...'` ou script lido da entrada padrão: não há arquivo para achar.
    if ($script eq '-e' || $script eq '-') {
        $Bin = $RealBin = $Dir = $RealDir = getcwd();
        $Script = $RealScript = $script;
        return;
    }

    # Chamado só pelo nome (sem barra): procura no PATH, como o shell.
    if ($script !~ m{/}) {
        for my $dir (File::Spec->path()) {
            my $candidate = File::Spec->catfile($dir, $script);
            if (-f $candidate && -x _) {
                $script = $candidate;
                last;
            }
        }
    }

    $Script = basename($script);
    $Bin = abs_path(dirname($script));

    # Segue a cadeia de links simbólicos até o arquivo real.
    my $real = $script;
    while (-l $real) {
        my $target = readlink($real);
        $real = File::Spec->file_name_is_absolute($target)
            ? $target
            : File::Spec->catfile(dirname($real), $target);
    }
    $RealScript = basename($real);
    $RealBin = abs_path(dirname($real));

    $Dir = $Bin;
    $RealDir = $RealBin;
}

init();

1;

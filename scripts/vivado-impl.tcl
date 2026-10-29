# Place & route e bitstream no Vivado, a partir do netlist EDIF do Yosys.
#
# Uso (normalmente pelo `make fpga`), de dentro do diretório de saída, para que
# o .Xil/ e os logs do Vivado fiquem lá:
#   vivado -mode batch -source vivado-impl.tcl -tclargs <design> <edif> <xdc> <part>
#
# Escreve, no diretório atual:
#   <design>-util.rpt    utilização do chip (report_utilization)
#   <design>-timing.rpt  relatório completo de timing (report_timing_summary)
#   <design>-clocks.txt  uma linha por clock: nome, período, folga de setup
#                        (lida pelo scripts/fpga-summary.sh)
#   <design>.bit         o bitstream, só se o timing passar
#
# Sai com código 1 se algum clock não fecha timing; o bitstream não é gerado.

lassign $argv design edif xdc part
set top ${design}_top

# O XDC da placa descreve todos os pinos, mas cada top usa só alguns. As
# restrições de portas que não existem viram INFO, em vez de CRITICAL WARNING.
# Uma porta do top sem pino continua sendo erro, no DRC do write_bitstream.
set_msg_config -id {Vivado 12-584} -new_severity INFO
set_msg_config -id {Common 17-55} -new_severity INFO
set_msg_config -id {Vivado 12-4739} -new_severity INFO

read_edif $edif
read_xdc $xdc
link_design -part $part -top $top

opt_design
place_design
route_design

report_utilization -file $design-util.rpt
report_timing_summary -file $design-timing.rpt

# Pior folga de setup de cada clock. Folga negativa = o clock não fecha timing.
set timing_ok 1
set fh [open $design-clocks.txt w]
foreach clk [get_clocks] {
    set path [get_timing_paths -setup -max_paths 1 -group $clk]
    set slack [expr {$path eq "" ? "" : [get_property SLACK $path]}]
    if {$slack eq ""} {
        set slack none
    } elseif {$slack < 0} {
        set timing_ok 0
    }
    puts $fh "$clk [get_property PERIOD $clk] $slack"
}
close $fh

# Hold: não tem frequência associada, só passa ou falha.
set hold [get_timing_paths -hold -max_paths 1]
if {$hold ne "" && [get_property SLACK $hold] < 0} {
    puts "ERRO: violação de hold (folga [get_property SLACK $hold] ns)."
    set timing_ok 0
}

if {!$timing_ok} {
    exit 1
}

write_bitstream -force $design.bit

# Nexys A7-100T (XC7A100T-1CSG324C): pinos da placa.
#
# Os nomes em get_ports são as portas do top da placa (fpga/<design>_top.sv).
# Todas as linhas ficam ativas: as que não têm porta correspondente no top
# são ignoradas (scripts/vivado-impl.tcl rebaixa esse aviso para INFO). Uma
# porta do top sem pino aqui faz o bitstream falhar (DRC UCIO-1 ou NSTD-1),
# então um nome digitado errado não passa despercebido.
#
# Barramentos começam em 0 e usam colchetes: sw[0], led[15], seg[6].
# O comentário no fim de cada linha é o nome do sinal no esquemático.
#
# Fonte dos pinos: Nexys-A7-100T-Master.xdc da Digilent
# (https://github.com/Digilent/digilent-xdc).

# Configuração: os bancos de configuração são de 3,3 V.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Clock: oscilador de 100 MHz.
set_property -dict {PACKAGE_PIN E3   IOSTANDARD LVCMOS33} [get_ports {clk}]     ; # clk100mhz
create_clock -name sys_clk -period 10.000 [get_ports {clk}]

# Chaves sw[15:0]: valem 1 para cima. sw[8] e sw[9] ficam no banco 34,
# que é de 1,8 V (LVCMOS18).
set_property -dict {PACKAGE_PIN J15  IOSTANDARD LVCMOS33} [get_ports {sw[0]}]   ; # sw[0]
set_property -dict {PACKAGE_PIN L16  IOSTANDARD LVCMOS33} [get_ports {sw[1]}]   ; # sw[1]
set_property -dict {PACKAGE_PIN M13  IOSTANDARD LVCMOS33} [get_ports {sw[2]}]   ; # sw[2]
set_property -dict {PACKAGE_PIN R15  IOSTANDARD LVCMOS33} [get_ports {sw[3]}]   ; # sw[3]
set_property -dict {PACKAGE_PIN R17  IOSTANDARD LVCMOS33} [get_ports {sw[4]}]   ; # sw[4]
set_property -dict {PACKAGE_PIN T18  IOSTANDARD LVCMOS33} [get_ports {sw[5]}]   ; # sw[5]
set_property -dict {PACKAGE_PIN U18  IOSTANDARD LVCMOS33} [get_ports {sw[6]}]   ; # sw[6]
set_property -dict {PACKAGE_PIN R13  IOSTANDARD LVCMOS33} [get_ports {sw[7]}]   ; # sw[7]
set_property -dict {PACKAGE_PIN T8   IOSTANDARD LVCMOS18} [get_ports {sw[8]}]   ; # sw[8]
set_property -dict {PACKAGE_PIN U8   IOSTANDARD LVCMOS18} [get_ports {sw[9]}]   ; # sw[9]
set_property -dict {PACKAGE_PIN R16  IOSTANDARD LVCMOS33} [get_ports {sw[10]}]  ; # sw[10]
set_property -dict {PACKAGE_PIN T13  IOSTANDARD LVCMOS33} [get_ports {sw[11]}]  ; # sw[11]
set_property -dict {PACKAGE_PIN H6   IOSTANDARD LVCMOS33} [get_ports {sw[12]}]  ; # sw[12]
set_property -dict {PACKAGE_PIN U12  IOSTANDARD LVCMOS33} [get_ports {sw[13]}]  ; # sw[13]
set_property -dict {PACKAGE_PIN U11  IOSTANDARD LVCMOS33} [get_ports {sw[14]}]  ; # sw[14]
set_property -dict {PACKAGE_PIN V10  IOSTANDARD LVCMOS33} [get_ports {sw[15]}]  ; # sw[15]

# LEDs led[15:0]: acendem com 1.
set_property -dict {PACKAGE_PIN H17  IOSTANDARD LVCMOS33} [get_ports {led[0]}]  ; # led[0]
set_property -dict {PACKAGE_PIN K15  IOSTANDARD LVCMOS33} [get_ports {led[1]}]  ; # led[1]
set_property -dict {PACKAGE_PIN J13  IOSTANDARD LVCMOS33} [get_ports {led[2]}]  ; # led[2]
set_property -dict {PACKAGE_PIN N14  IOSTANDARD LVCMOS33} [get_ports {led[3]}]  ; # led[3]
set_property -dict {PACKAGE_PIN R18  IOSTANDARD LVCMOS33} [get_ports {led[4]}]  ; # led[4]
set_property -dict {PACKAGE_PIN V17  IOSTANDARD LVCMOS33} [get_ports {led[5]}]  ; # led[5]
set_property -dict {PACKAGE_PIN U17  IOSTANDARD LVCMOS33} [get_ports {led[6]}]  ; # led[6]
set_property -dict {PACKAGE_PIN U16  IOSTANDARD LVCMOS33} [get_ports {led[7]}]  ; # led[7]
set_property -dict {PACKAGE_PIN V16  IOSTANDARD LVCMOS33} [get_ports {led[8]}]  ; # led[8]
set_property -dict {PACKAGE_PIN T15  IOSTANDARD LVCMOS33} [get_ports {led[9]}]  ; # led[9]
set_property -dict {PACKAGE_PIN U14  IOSTANDARD LVCMOS33} [get_ports {led[10]}] ; # led[10]
set_property -dict {PACKAGE_PIN T16  IOSTANDARD LVCMOS33} [get_ports {led[11]}] ; # led[11]
set_property -dict {PACKAGE_PIN V15  IOSTANDARD LVCMOS33} [get_ports {led[12]}] ; # led[12]
set_property -dict {PACKAGE_PIN V14  IOSTANDARD LVCMOS33} [get_ports {led[13]}] ; # led[13]
set_property -dict {PACKAGE_PIN V12  IOSTANDARD LVCMOS33} [get_ports {led[14]}] ; # led[14]
set_property -dict {PACKAGE_PIN V11  IOSTANDARD LVCMOS33} [get_ports {led[15]}] ; # led[15]

# LEDs RGB (LD16 e LD17): acendem com 1. Em 1 constante o brilho é
# muito forte; use PWM.
set_property -dict {PACKAGE_PIN R12  IOSTANDARD LVCMOS33} [get_ports {led16_b}] ; # led16_b
set_property -dict {PACKAGE_PIN M16  IOSTANDARD LVCMOS33} [get_ports {led16_g}] ; # led16_g
set_property -dict {PACKAGE_PIN N15  IOSTANDARD LVCMOS33} [get_ports {led16_r}] ; # led16_r
set_property -dict {PACKAGE_PIN G14  IOSTANDARD LVCMOS33} [get_ports {led17_b}] ; # led17_b
set_property -dict {PACKAGE_PIN R11  IOSTANDARD LVCMOS33} [get_ports {led17_g}] ; # led17_g
set_property -dict {PACKAGE_PIN N16  IOSTANDARD LVCMOS33} [get_ports {led17_r}] ; # led17_r

# Display de 7 segmentos, 8 dígitos, anodo comum: segmentos (seg, dp) e
# dígitos (an) acendem com 0. seg[0] é o segmento A (CA) ... seg[6] é o G (CG).
set_property -dict {PACKAGE_PIN T10  IOSTANDARD LVCMOS33} [get_ports {seg[0]}]  ; # ca
set_property -dict {PACKAGE_PIN R10  IOSTANDARD LVCMOS33} [get_ports {seg[1]}]  ; # cb
set_property -dict {PACKAGE_PIN K16  IOSTANDARD LVCMOS33} [get_ports {seg[2]}]  ; # cc
set_property -dict {PACKAGE_PIN K13  IOSTANDARD LVCMOS33} [get_ports {seg[3]}]  ; # cd
set_property -dict {PACKAGE_PIN P15  IOSTANDARD LVCMOS33} [get_ports {seg[4]}]  ; # ce
set_property -dict {PACKAGE_PIN T11  IOSTANDARD LVCMOS33} [get_ports {seg[5]}]  ; # cf
set_property -dict {PACKAGE_PIN L18  IOSTANDARD LVCMOS33} [get_ports {seg[6]}]  ; # cg
set_property -dict {PACKAGE_PIN H15  IOSTANDARD LVCMOS33} [get_ports {dp}]      ; # dp
set_property -dict {PACKAGE_PIN J17  IOSTANDARD LVCMOS33} [get_ports {an[0]}]   ; # an[0]
set_property -dict {PACKAGE_PIN J18  IOSTANDARD LVCMOS33} [get_ports {an[1]}]   ; # an[1]
set_property -dict {PACKAGE_PIN T9   IOSTANDARD LVCMOS33} [get_ports {an[2]}]   ; # an[2]
set_property -dict {PACKAGE_PIN J14  IOSTANDARD LVCMOS33} [get_ports {an[3]}]   ; # an[3]
set_property -dict {PACKAGE_PIN P14  IOSTANDARD LVCMOS33} [get_ports {an[4]}]   ; # an[4]
set_property -dict {PACKAGE_PIN T14  IOSTANDARD LVCMOS33} [get_ports {an[5]}]   ; # an[5]
set_property -dict {PACKAGE_PIN K2   IOSTANDARD LVCMOS33} [get_ports {an[6]}]   ; # an[6]
set_property -dict {PACKAGE_PIN U13  IOSTANDARD LVCMOS33} [get_ports {an[7]}]   ; # an[7]

# Botão CPU RESET: vale 0 enquanto pressionado (ativo baixo).
set_property -dict {PACKAGE_PIN C12  IOSTANDARD LVCMOS33} [get_ports {cpu_resetn}]; # cpu_resetn

# Botões: valem 1 enquanto pressionados.
set_property -dict {PACKAGE_PIN N17  IOSTANDARD LVCMOS33} [get_ports {btnc}]    ; # btnc
set_property -dict {PACKAGE_PIN M18  IOSTANDARD LVCMOS33} [get_ports {btnu}]    ; # btnu
set_property -dict {PACKAGE_PIN P17  IOSTANDARD LVCMOS33} [get_ports {btnl}]    ; # btnl
set_property -dict {PACKAGE_PIN M17  IOSTANDARD LVCMOS33} [get_ports {btnr}]    ; # btnr
set_property -dict {PACKAGE_PIN P18  IOSTANDARD LVCMOS33} [get_ports {btnd}]    ; # btnd

# Conectores Pmod: ja[0] a ja[3] são os pinos 1 a 4; ja[4] a ja[7] são os
# pinos 7 a 10 (os pinos 5, 6, 11 e 12 são GND e VCC). Idem para jb, jc e jd.
set_property -dict {PACKAGE_PIN C17  IOSTANDARD LVCMOS33} [get_ports {ja[0]}]   ; # ja[1]
set_property -dict {PACKAGE_PIN D18  IOSTANDARD LVCMOS33} [get_ports {ja[1]}]   ; # ja[2]
set_property -dict {PACKAGE_PIN E18  IOSTANDARD LVCMOS33} [get_ports {ja[2]}]   ; # ja[3]
set_property -dict {PACKAGE_PIN G17  IOSTANDARD LVCMOS33} [get_ports {ja[3]}]   ; # ja[4]
set_property -dict {PACKAGE_PIN D17  IOSTANDARD LVCMOS33} [get_ports {ja[4]}]   ; # ja[7]
set_property -dict {PACKAGE_PIN E17  IOSTANDARD LVCMOS33} [get_ports {ja[5]}]   ; # ja[8]
set_property -dict {PACKAGE_PIN F18  IOSTANDARD LVCMOS33} [get_ports {ja[6]}]   ; # ja[9]
set_property -dict {PACKAGE_PIN G18  IOSTANDARD LVCMOS33} [get_ports {ja[7]}]   ; # ja[10]

set_property -dict {PACKAGE_PIN D14  IOSTANDARD LVCMOS33} [get_ports {jb[0]}]   ; # jb[1]
set_property -dict {PACKAGE_PIN F16  IOSTANDARD LVCMOS33} [get_ports {jb[1]}]   ; # jb[2]
set_property -dict {PACKAGE_PIN G16  IOSTANDARD LVCMOS33} [get_ports {jb[2]}]   ; # jb[3]
set_property -dict {PACKAGE_PIN H14  IOSTANDARD LVCMOS33} [get_ports {jb[3]}]   ; # jb[4]
set_property -dict {PACKAGE_PIN E16  IOSTANDARD LVCMOS33} [get_ports {jb[4]}]   ; # jb[7]
set_property -dict {PACKAGE_PIN F13  IOSTANDARD LVCMOS33} [get_ports {jb[5]}]   ; # jb[8]
set_property -dict {PACKAGE_PIN G13  IOSTANDARD LVCMOS33} [get_ports {jb[6]}]   ; # jb[9]
set_property -dict {PACKAGE_PIN H16  IOSTANDARD LVCMOS33} [get_ports {jb[7]}]   ; # jb[10]

set_property -dict {PACKAGE_PIN K1   IOSTANDARD LVCMOS33} [get_ports {jc[0]}]   ; # jc[1]
set_property -dict {PACKAGE_PIN F6   IOSTANDARD LVCMOS33} [get_ports {jc[1]}]   ; # jc[2]
set_property -dict {PACKAGE_PIN J2   IOSTANDARD LVCMOS33} [get_ports {jc[2]}]   ; # jc[3]
set_property -dict {PACKAGE_PIN G6   IOSTANDARD LVCMOS33} [get_ports {jc[3]}]   ; # jc[4]
set_property -dict {PACKAGE_PIN E7   IOSTANDARD LVCMOS33} [get_ports {jc[4]}]   ; # jc[7]
set_property -dict {PACKAGE_PIN J3   IOSTANDARD LVCMOS33} [get_ports {jc[5]}]   ; # jc[8]
set_property -dict {PACKAGE_PIN J4   IOSTANDARD LVCMOS33} [get_ports {jc[6]}]   ; # jc[9]
set_property -dict {PACKAGE_PIN E6   IOSTANDARD LVCMOS33} [get_ports {jc[7]}]   ; # jc[10]

set_property -dict {PACKAGE_PIN H4   IOSTANDARD LVCMOS33} [get_ports {jd[0]}]   ; # jd[1]
set_property -dict {PACKAGE_PIN H1   IOSTANDARD LVCMOS33} [get_ports {jd[1]}]   ; # jd[2]
set_property -dict {PACKAGE_PIN G1   IOSTANDARD LVCMOS33} [get_ports {jd[2]}]   ; # jd[3]
set_property -dict {PACKAGE_PIN G3   IOSTANDARD LVCMOS33} [get_ports {jd[3]}]   ; # jd[4]
set_property -dict {PACKAGE_PIN H2   IOSTANDARD LVCMOS33} [get_ports {jd[4]}]   ; # jd[7]
set_property -dict {PACKAGE_PIN G4   IOSTANDARD LVCMOS33} [get_ports {jd[5]}]   ; # jd[8]
set_property -dict {PACKAGE_PIN G2   IOSTANDARD LVCMOS33} [get_ports {jd[6]}]   ; # jd[9]
set_property -dict {PACKAGE_PIN F3   IOSTANDARD LVCMOS33} [get_ports {jd[7]}]   ; # jd[10]

# Pmod JXADC (entradas analógicas do XADC; aqui como I/O digital).
set_property -dict {PACKAGE_PIN A14  IOSTANDARD LVCMOS33} [get_ports {xa_n[0]}] ; # xa_n[1]
set_property -dict {PACKAGE_PIN A13  IOSTANDARD LVCMOS33} [get_ports {xa_p[0]}] ; # xa_p[1]
set_property -dict {PACKAGE_PIN A16  IOSTANDARD LVCMOS33} [get_ports {xa_n[1]}] ; # xa_n[2]
set_property -dict {PACKAGE_PIN A15  IOSTANDARD LVCMOS33} [get_ports {xa_p[1]}] ; # xa_p[2]
set_property -dict {PACKAGE_PIN B17  IOSTANDARD LVCMOS33} [get_ports {xa_n[2]}] ; # xa_n[3]
set_property -dict {PACKAGE_PIN B16  IOSTANDARD LVCMOS33} [get_ports {xa_p[2]}] ; # xa_p[3]
set_property -dict {PACKAGE_PIN A18  IOSTANDARD LVCMOS33} [get_ports {xa_n[3]}] ; # xa_n[4]
set_property -dict {PACKAGE_PIN B18  IOSTANDARD LVCMOS33} [get_ports {xa_p[3]}] ; # xa_p[4]

# VGA: 4 bits por cor.
set_property -dict {PACKAGE_PIN A3   IOSTANDARD LVCMOS33} [get_ports {vga_r[0]}]; # vga_r[0]
set_property -dict {PACKAGE_PIN B4   IOSTANDARD LVCMOS33} [get_ports {vga_r[1]}]; # vga_r[1]
set_property -dict {PACKAGE_PIN C5   IOSTANDARD LVCMOS33} [get_ports {vga_r[2]}]; # vga_r[2]
set_property -dict {PACKAGE_PIN A4   IOSTANDARD LVCMOS33} [get_ports {vga_r[3]}]; # vga_r[3]
set_property -dict {PACKAGE_PIN C6   IOSTANDARD LVCMOS33} [get_ports {vga_g[0]}]; # vga_g[0]
set_property -dict {PACKAGE_PIN A5   IOSTANDARD LVCMOS33} [get_ports {vga_g[1]}]; # vga_g[1]
set_property -dict {PACKAGE_PIN B6   IOSTANDARD LVCMOS33} [get_ports {vga_g[2]}]; # vga_g[2]
set_property -dict {PACKAGE_PIN A6   IOSTANDARD LVCMOS33} [get_ports {vga_g[3]}]; # vga_g[3]
set_property -dict {PACKAGE_PIN B7   IOSTANDARD LVCMOS33} [get_ports {vga_b[0]}]; # vga_b[0]
set_property -dict {PACKAGE_PIN C7   IOSTANDARD LVCMOS33} [get_ports {vga_b[1]}]; # vga_b[1]
set_property -dict {PACKAGE_PIN D7   IOSTANDARD LVCMOS33} [get_ports {vga_b[2]}]; # vga_b[2]
set_property -dict {PACKAGE_PIN D8   IOSTANDARD LVCMOS33} [get_ports {vga_b[3]}]; # vga_b[3]
set_property -dict {PACKAGE_PIN B11  IOSTANDARD LVCMOS33} [get_ports {vga_hs}]  ; # vga_hs
set_property -dict {PACKAGE_PIN B12  IOSTANDARD LVCMOS33} [get_ports {vga_vs}]  ; # vga_vs

# Cartão micro SD.
set_property -dict {PACKAGE_PIN E2   IOSTANDARD LVCMOS33} [get_ports {sd_reset}]; # sd_reset
set_property -dict {PACKAGE_PIN A1   IOSTANDARD LVCMOS33} [get_ports {sd_cd}]   ; # sd_cd
set_property -dict {PACKAGE_PIN B1   IOSTANDARD LVCMOS33} [get_ports {sd_sck}]  ; # sd_sck
set_property -dict {PACKAGE_PIN C1   IOSTANDARD LVCMOS33} [get_ports {sd_cmd}]  ; # sd_cmd
set_property -dict {PACKAGE_PIN C2   IOSTANDARD LVCMOS33} [get_ports {sd_dat[0]}]; # sd_dat[0]
set_property -dict {PACKAGE_PIN E1   IOSTANDARD LVCMOS33} [get_ports {sd_dat[1]}]; # sd_dat[1]
set_property -dict {PACKAGE_PIN F1   IOSTANDARD LVCMOS33} [get_ports {sd_dat[2]}]; # sd_dat[2]
set_property -dict {PACKAGE_PIN D2   IOSTANDARD LVCMOS33} [get_ports {sd_dat[3]}]; # sd_dat[3]

# Acelerômetro ADXL362 (SPI).
set_property -dict {PACKAGE_PIN E15  IOSTANDARD LVCMOS33} [get_ports {acl_miso}]; # acl_miso
set_property -dict {PACKAGE_PIN F14  IOSTANDARD LVCMOS33} [get_ports {acl_mosi}]; # acl_mosi
set_property -dict {PACKAGE_PIN F15  IOSTANDARD LVCMOS33} [get_ports {acl_sclk}]; # acl_sclk
set_property -dict {PACKAGE_PIN D15  IOSTANDARD LVCMOS33} [get_ports {acl_csn}] ; # acl_csn
set_property -dict {PACKAGE_PIN B13  IOSTANDARD LVCMOS33} [get_ports {acl_int[0]}]; # acl_int[1]
set_property -dict {PACKAGE_PIN C16  IOSTANDARD LVCMOS33} [get_ports {acl_int[1]}]; # acl_int[2]

# Sensor de temperatura ADT7420 (I2C).
set_property -dict {PACKAGE_PIN C14  IOSTANDARD LVCMOS33} [get_ports {tmp_scl}] ; # tmp_scl
set_property -dict {PACKAGE_PIN C15  IOSTANDARD LVCMOS33} [get_ports {tmp_sda}] ; # tmp_sda
set_property -dict {PACKAGE_PIN D13  IOSTANDARD LVCMOS33} [get_ports {tmp_int}] ; # tmp_int
set_property -dict {PACKAGE_PIN B14  IOSTANDARD LVCMOS33} [get_ports {tmp_ct}]  ; # tmp_ct

# Microfone (saída PDM).
set_property -dict {PACKAGE_PIN J5   IOSTANDARD LVCMOS33} [get_ports {m_clk}]   ; # m_clk
set_property -dict {PACKAGE_PIN H5   IOSTANDARD LVCMOS33} [get_ports {m_data}]  ; # m_data
set_property -dict {PACKAGE_PIN F5   IOSTANDARD LVCMOS33} [get_ports {m_lrsel}] ; # m_lrsel

# Saída de áudio PWM (aud_sd = 1 liga o amplificador).
set_property -dict {PACKAGE_PIN A11  IOSTANDARD LVCMOS33} [get_ports {aud_pwm}] ; # aud_pwm
set_property -dict {PACKAGE_PIN D12  IOSTANDARD LVCMOS33} [get_ports {aud_sd}]  ; # aud_sd

# USB-UART (FT2232HQ). Os nomes são do ponto de vista do PC: uart_txd_in
# é entrada da FPGA (dados do PC) e uart_rxd_out é saída da FPGA.
set_property -dict {PACKAGE_PIN C4   IOSTANDARD LVCMOS33} [get_ports {uart_txd_in}]; # uart_txd_in
set_property -dict {PACKAGE_PIN D4   IOSTANDARD LVCMOS33} [get_ports {uart_rxd_out}]; # uart_rxd_out
set_property -dict {PACKAGE_PIN D3   IOSTANDARD LVCMOS33} [get_ports {uart_cts}]; # uart_cts
set_property -dict {PACKAGE_PIN E5   IOSTANDARD LVCMOS33} [get_ports {uart_rts}]; # uart_rts

# Teclado/mouse USB, convertido para PS/2 pelo microcontrolador da placa.
set_property -dict {PACKAGE_PIN F4   IOSTANDARD LVCMOS33} [get_ports {ps2_clk}] ; # ps2_clk
set_property -dict {PACKAGE_PIN B2   IOSTANDARD LVCMOS33} [get_ports {ps2_data}]; # ps2_data

# Ethernet (PHY LAN8720A, RMII).
set_property -dict {PACKAGE_PIN C9   IOSTANDARD LVCMOS33} [get_ports {eth_mdc}] ; # eth_mdc
set_property -dict {PACKAGE_PIN A9   IOSTANDARD LVCMOS33} [get_ports {eth_mdio}]; # eth_mdio
set_property -dict {PACKAGE_PIN B3   IOSTANDARD LVCMOS33} [get_ports {eth_rstn}]; # eth_rstn
set_property -dict {PACKAGE_PIN D9   IOSTANDARD LVCMOS33} [get_ports {eth_crsdv}]; # eth_crsdv
set_property -dict {PACKAGE_PIN C10  IOSTANDARD LVCMOS33} [get_ports {eth_rxerr}]; # eth_rxerr
set_property -dict {PACKAGE_PIN C11  IOSTANDARD LVCMOS33} [get_ports {eth_rxd[0]}]; # eth_rxd[0]
set_property -dict {PACKAGE_PIN D10  IOSTANDARD LVCMOS33} [get_ports {eth_rxd[1]}]; # eth_rxd[1]
set_property -dict {PACKAGE_PIN B9   IOSTANDARD LVCMOS33} [get_ports {eth_txen}]; # eth_txen
set_property -dict {PACKAGE_PIN A10  IOSTANDARD LVCMOS33} [get_ports {eth_txd[0]}]; # eth_txd[0]
set_property -dict {PACKAGE_PIN A8   IOSTANDARD LVCMOS33} [get_ports {eth_txd[1]}]; # eth_txd[1]
set_property -dict {PACKAGE_PIN D5   IOSTANDARD LVCMOS33} [get_ports {eth_refclk}]; # eth_refclk
set_property -dict {PACKAGE_PIN B8   IOSTANDARD LVCMOS33} [get_ports {eth_intn}]; # eth_intn

# Flash Quad SPI (a mesma que guarda o bitstream).
set_property -dict {PACKAGE_PIN K17  IOSTANDARD LVCMOS33} [get_ports {qspi_dq[0]}]; # qspi_dq[0]
set_property -dict {PACKAGE_PIN K18  IOSTANDARD LVCMOS33} [get_ports {qspi_dq[1]}]; # qspi_dq[1]
set_property -dict {PACKAGE_PIN L14  IOSTANDARD LVCMOS33} [get_ports {qspi_dq[2]}]; # qspi_dq[2]
set_property -dict {PACKAGE_PIN M14  IOSTANDARD LVCMOS33} [get_ports {qspi_dq[3]}]; # qspi_dq[3]
set_property -dict {PACKAGE_PIN L13  IOSTANDARD LVCMOS33} [get_ports {qspi_csn}]; # qspi_csn

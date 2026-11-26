# ==============================================================================
# SCRIPT TCL PARA ATRIBUICAO AUTOMATICA DE PINOS - DE0-CV (Cyclone V 5CEBA4F23C7)
# Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
# Como executar no Quartus: Tools -> Tcl Scripts... -> mapeamento_pinos.tcl -> Run
# ==============================================================================

package require ::quartus::project

# ------------------------------------------------------------------------------
# 1. CLOCK E RESET [Manual DE0-CV Secao 3.2 e 3.4]
# ------------------------------------------------------------------------------
set_location_assignment PIN_M9  -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50

set_location_assignment PIN_P22 -to RESET_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to RESET_N

# ------------------------------------------------------------------------------
# 2. BOTOES DE PRESSAO (KEY[3:0] - Ativos em Nivel Baixo '0') [Manual Tabela 3-2]
# ------------------------------------------------------------------------------
set_location_assignment PIN_U7  -to KEY[0] ;# Reset / Desbloqueio
set_location_assignment PIN_W9  -to KEY[1] ;# Disparo de leitura no Modo Simulacao
set_location_assignment PIN_M7  -to KEY[2] ;# Cadastrar ultimo cartao lido
set_location_assignment PIN_M6  -to KEY[3] ;# Limpar cartao cadastrado

for {set i 0} {$i < 4} {incr i} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY[$i]
}

# ------------------------------------------------------------------------------
# 3. CHAVES DE ENTRADA (SW[9:0]) [Manual Secao 3.2, Tabela 3-3]
# ------------------------------------------------------------------------------
set_location_assignment PIN_U13  -to SW[0]
set_location_assignment PIN_V13  -to SW[1]
set_location_assignment PIN_T13  -to SW[2]
set_location_assignment PIN_T12  -to SW[3]
set_location_assignment PIN_AA15 -to SW[4]
set_location_assignment PIN_AB15 -to SW[5]
set_location_assignment PIN_AA14 -to SW[6]
set_location_assignment PIN_AA13 -to SW[7]
set_location_assignment PIN_AB13 -to SW[8] ;# 0: Status ("OPEn"/"ErrO") | 1: UID Hex
set_location_assignment PIN_AB12 -to SW[9] ;# 0: Leitor RFID-RC522 Real | 1: Modo Chave SW[7:0]

for {set i 0} {$i < 10} {incr i} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[$i]
}

# ------------------------------------------------------------------------------
# 4. SAIDAS DE LEDS (LEDR[9:0]) [Manual Secao 3.2, Tabela 3-4]
# ------------------------------------------------------------------------------
set_location_assignment PIN_AA2 -to LEDR[0] ;# Estado Atual bit 0
set_location_assignment PIN_AA1 -to LEDR[1] ;# Estado Atual bit 1
set_location_assignment PIN_W2  -to LEDR[2] ;# Estado Atual bit 2
set_location_assignment PIN_Y3  -to LEDR[3] ;# Contador de Erros bit 0
set_location_assignment PIN_N2  -to LEDR[4] ;# Contador de Erros bit 1
set_location_assignment PIN_N1  -to LEDR[5] ;# Cartao Dinamico Cadastrado
set_location_assignment PIN_U2  -to LEDR[6] ;# Alarme de Sistema Bloqueado (S_BLOQUEADO)
set_location_assignment PIN_U1  -to LEDR[7] ;# Sinal Dividido (Pisca a 2 Hz - Divisor de Frequencia)
set_location_assignment PIN_L2  -to LEDR[8] ;# Acesso Negado (S_NEGADO)
set_location_assignment PIN_L1  -to LEDR[9] ;# Acesso Autorizado / Trava Aberta (S_AUTORIZADO)

for {set i 0} {$i < 10} {incr i} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[$i]
}

# ------------------------------------------------------------------------------
# 5. DISPLAYS DE 7 SEGMENTOS (HEX0 a HEX5 - Anodo Comum) [Manual Tabela 3-5]
# ------------------------------------------------------------------------------
# HEX0
set_location_assignment PIN_U21  -to HEX0[0]
set_location_assignment PIN_V21  -to HEX0[1]
set_location_assignment PIN_W22  -to HEX0[2]
set_location_assignment PIN_W21  -to HEX0[3]
set_location_assignment PIN_Y22  -to HEX0[4]
set_location_assignment PIN_Y21  -to HEX0[5]
set_location_assignment PIN_AA22 -to HEX0[6]

# HEX1
set_location_assignment PIN_AA20 -to HEX1[0]
set_location_assignment PIN_AB20 -to HEX1[1]
set_location_assignment PIN_AA19 -to HEX1[2]
set_location_assignment PIN_AA18 -to HEX1[3]
set_location_assignment PIN_AB18 -to HEX1[4]
set_location_assignment PIN_AA17 -to HEX1[5]
set_location_assignment PIN_U22  -to HEX1[6]

# HEX2
set_location_assignment PIN_Y19  -to HEX2[0]
set_location_assignment PIN_AB17 -to HEX2[1]
set_location_assignment PIN_AA10 -to HEX2[2]
set_location_assignment PIN_Y14  -to HEX2[3]
set_location_assignment PIN_V14  -to HEX2[4]
set_location_assignment PIN_AB22 -to HEX2[5]
set_location_assignment PIN_AB21 -to HEX2[6]

# HEX3
set_location_assignment PIN_Y16  -to HEX3[0]
set_location_assignment PIN_W16  -to HEX3[1]
set_location_assignment PIN_Y17  -to HEX3[2]
set_location_assignment PIN_V16  -to HEX3[3]
set_location_assignment PIN_U17  -to HEX3[4]
set_location_assignment PIN_V18  -to HEX3[5]
set_location_assignment PIN_V19  -to HEX3[6]

# HEX4
set_location_assignment PIN_U20  -to HEX4[0]
set_location_assignment PIN_Y20  -to HEX4[1]
set_location_assignment PIN_V20  -to HEX4[2]
set_location_assignment PIN_U16  -to HEX4[3]
set_location_assignment PIN_U15  -to HEX4[4]
set_location_assignment PIN_Y15  -to HEX4[5]
set_location_assignment PIN_P9   -to HEX4[6]

# HEX5
set_location_assignment PIN_N9   -to HEX5[0]
set_location_assignment PIN_M8   -to HEX5[1]
set_location_assignment PIN_T14  -to HEX5[2]
set_location_assignment PIN_P14  -to HEX5[3]
set_location_assignment PIN_C1   -to HEX5[4]
set_location_assignment PIN_C2   -to HEX5[5]
set_location_assignment PIN_W19  -to HEX5[6]

for {set i 0} {$i < 7} {incr i} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to HEX0[$i]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to HEX1[$i]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to HEX2[$i]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to HEX3[$i]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to HEX4[$i]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to HEX5[$i]
}

# ------------------------------------------------------------------------------
# 6. MODULO RFID-RC522 (SPI) NO HEADER GPIO_0 (JP1) [Manual Tabela 3-11]
# ------------------------------------------------------------------------------
set_location_assignment PIN_N16 -to RC522_CS_N    ;# GPIO_0[0] (Pino 1 do JP1)
set_location_assignment PIN_B16 -to RC522_SCK     ;# GPIO_0[1] (Pino 2 do JP1)
set_location_assignment PIN_M16 -to RC522_MOSI    ;# GPIO_0[2] (Pino 3 do JP1)
set_location_assignment PIN_C16 -to RC522_MISO    ;# GPIO_0[3] (Pino 4 do JP1)
set_location_assignment PIN_D17 -to RC522_RST_N   ;# GPIO_0[4] (Pino 5 do JP1)

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to RC522_CS_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to RC522_SCK
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to RC522_MOSI
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to RC522_MISO
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON  -to RC522_MISO
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to RC522_RST_N

# Salva as atribuicoes no arquivo .qsf do projeto
export_assignments

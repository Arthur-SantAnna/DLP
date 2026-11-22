# ==============================================================================
# SCRIPT TCL PARA ATRIBUIÇÃO AUTOMÁTICA DE PINOS - DE0-CV (Cyclone V 5CEBA4F23C7N)
# ==============================================================================

package require ::quartus::project

# ------------------------------------------------------------------------------
# 1. CLOCK E RESET
# ------------------------------------------------------------------------------
# Clock de 50 MHz (PIN_M9 - CLOCK_50) [Manual Seção 3.4, Tabela 3-6]
set_location_assignment PIN_M9 -to clk_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk_50

# Reset alterado para a Chave SW9 (PIN_AB12 - Lógica: 1 = CIMA, 0 = BAIXO) [Manual Tabela 3-3]
set_location_assignment PIN_AB12 -to rst
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to rst

# ------------------------------------------------------------------------------
# 2. CHAVES DE ENTRADA (SW) [Manual Seção 3.2, Tabela 3-3]
# ------------------------------------------------------------------------------
# Sentido (SW0 - PIN_U13)
set_location_assignment PIN_U13 -to sentido
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sentido

# Pausa (SW1 - PIN_V13)
set_location_assignment PIN_V13 -to pausa
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to pausa

# Modo de Exibição (SW2: modo[0] - PIN_T13 / SW3: modo[1] - PIN_T12)
set_location_assignment PIN_T13 -to modo[0]
set_location_assignment PIN_T12 -to modo[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to modo[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to modo[1]

# ------------------------------------------------------------------------------
# 3. SAÍDAS DE LEDS (LEDR) [Manual Seção 3.2, Tabela 3-4]
# ------------------------------------------------------------------------------
# LED do Sinal Dividido (LEDR1 - PIN_AA1) -> Pisca a 2 Hz
set_location_assignment PIN_AA1 -to sinal_div
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sinal_div

# Pulso de Avanço (LEDR0 - PIN_AA2) -> Pulso de 20 ns
set_location_assignment PIN_AA2 -to pulso_avanco
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to pulso_avanco

# Indicadores de Estado
set_location_assignment PIN_W2 -to cheio    ;# LEDR2 - PIN_W2
set_location_assignment PIN_Y3 -to vazio    ;# LEDR3 - PIN_Y3
set_location_assignment PIN_N2 -to alerta   ;# LEDR4 - PIN_N2
set_location_assignment PIN_N1 -to erro     ;# LEDR5 - PIN_N1

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to cheio
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to vazio
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to alerta
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to erro

# ------------------------------------------------------------------------------
# 4. DISPLAYS DE 7 SEGMENTOS (HEX0 e HEX1 - Ânodo Comum) [Manual Seção 3.3, Tabela 3-5]
# ------------------------------------------------------------------------------
# HEX0 (Unidades)
set_location_assignment PIN_U21  -to hex0[0]
set_location_assignment PIN_V21  -to hex0[1]
set_location_assignment PIN_W22  -to hex0[2]
set_location_assignment PIN_W21  -to hex0[3]
set_location_assignment PIN_Y22  -to hex0[4]
set_location_assignment PIN_Y21  -to hex0[5]
set_location_assignment PIN_AA22 -to hex0[6]

# HEX1 (Dezenas)
set_location_assignment PIN_AA20 -to hex1[0]
set_location_assignment PIN_AB20 -to hex1[1]
set_location_assignment PIN_AA19 -to hex1[2]
set_location_assignment PIN_AA18 -to hex1[3]
set_location_assignment PIN_AB18 -to hex1[4]
set_location_assignment PIN_AA17 -to hex1[5]
set_location_assignment PIN_U22  -to hex1[6]

# Define o Padrão I/O LVTTL de 3.3V para os Displays [Manual Seção 3.3]
for {set i 0} {$i < 7} {incr i} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to hex0[$i]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to hex1[$i]
}

# Salva as atribuições no projeto (.qsf)
export_assignments
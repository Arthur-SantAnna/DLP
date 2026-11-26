# =====================================================================
# pinos_pratica03.tcl - Pinos da DE0-CV para o top_gerador_sinal
# Fonte: DE0-CV User Manual v1.12 (tabelas 3-2, 3-4, 3-5 e 3-6)
#
# Uso: com o projeto aberto, Tools > Tcl Scripts... > este arquivo > Run
# Depois: Processing > Start Compilation e conferir no Pin Planner.
# =====================================================================

package require ::quartus::project

# Dispositivo da DE0-CV
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CEBA4F23C7

proc pino {sinal local} {
    set_location_assignment $local -to $sinal
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $sinal
}

# ---- Clock de 50 MHz ----
pino CLOCK_50 PIN_M9

# ---- Botões (ativos em '0'); KEY[0] = reset ----
pino KEY[0] PIN_U7
pino KEY[1] PIN_W9
pino KEY[2] PIN_M7
pino KEY[3] PIN_M6

# ---- LEDs vermelhos: LEDR[0] = y, LEDR[9] = clock lento ----
pino LEDR[0] PIN_AA2
pino LEDR[1] PIN_AA1
pino LEDR[2] PIN_W2
pino LEDR[3] PIN_Y3
pino LEDR[4] PIN_N2
pino LEDR[5] PIN_N1
pino LEDR[6] PIN_U2
pino LEDR[7] PIN_U1
pino LEDR[8] PIN_L2
pino LEDR[9] PIN_L1

# ---- Display HEX0 (anodo comum, segmento acende com '0') ----
# HEX0[0]=a  [1]=b  [2]=c  [3]=d  [4]=e  [5]=f  [6]=g
pino HEX0[0] PIN_U21
pino HEX0[1] PIN_V21
pino HEX0[2] PIN_W22
pino HEX0[3] PIN_W21
pino HEX0[4] PIN_Y22
pino HEX0[5] PIN_Y21
pino HEX0[6] PIN_AA22

export_assignments

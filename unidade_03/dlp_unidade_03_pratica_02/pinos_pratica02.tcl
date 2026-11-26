# =====================================================================
# pinos_pratica02.tcl - Pinos da DE0-CV para o top_motor_passo
# Fonte: DE0-CV User Manual v1.12 (tabelas 3-2 a 3-7)
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

# ---- Chaves: SW[0] = sentido, SW[1] = velocidade ----
pino SW[0] PIN_U13
pino SW[1] PIN_V13
pino SW[2] PIN_T13
pino SW[3] PIN_T12
pino SW[4] PIN_AA15
pino SW[5] PIN_AB15
pino SW[6] PIN_AA14
pino SW[7] PIN_AA13
pino SW[8] PIN_AB13
pino SW[9] PIN_AB12

# ---- LEDs vermelhos: LEDR[3..0] = fases D C B A, LEDR[8] = sentido, LEDR[9] = clock ----
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

# ---- Header GPIO_0 (JP1) -> IN1..IN4 do driver ULN2003 ----
# GPIO_0[0]=A (IN1)  [1]=B (IN2)  [2]=C (IN3)  [3]=D (IN4)
pino GPIO_0[0] PIN_N16
pino GPIO_0[1] PIN_B16
pino GPIO_0[2] PIN_M16
pino GPIO_0[3] PIN_C16

export_assignments

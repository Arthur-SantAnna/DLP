# Prática 02 — Acionamento de Motor de Passo Unipolar (Modo Wave)

Implementação em VHDL de uma Máquina de Estados Finita (FSM) de Moore para acionamento de um **motor de passo unipolar no modo wave** (uma fase energizada por vez), desenvolvido para a disciplina **Dispositivos Lógicos Programáveis (DLP)** — **SENAI CIMATEC** (Prof. João Castelo, Unidade 03 — Prática Obrigatória, Equipe Giulia).

---

## Descrição da Prática

> **Enunciado (Slide 21 — Prática 02):**
> *Projetar uma máquina de estados em VHDL para acionar um motor de passo unipolar no modo wave, com entradas `Reset`, `Clock` e `Sentido` (`S='0'` horário, `S='1'` anti-horário) e saídas de fase `A`, `B`, `C` e `D`.*

No **modo wave**, apenas uma bobina é energizada por passo, garantindo sequência cíclica de 4 estados em ambos os sentidos de rotação.

---

## Máquina de Estados (`motor_passo_wave.vhd`)

- **Estados:** `FASE_A`, `FASE_B`, `FASE_C`, `FASE_D`
- **Reset (`reset`):** assíncrono, ativo em nível baixo (`'0'`), retorna ao estado inicial `FASE_A`.
- **Saídas (Moore):** dependem apenas do estado atual.

| Estado Atual | Próximo (`sentido = '0'` Horário) | Próximo (`sentido = '1'` Anti-horário) | Saídas `(A, B, C, D)` | `HEX0` (Fase) |
| :---: | :---: | :---: | :---: | :---: |
| `FASE_A` | `FASE_B` | `FASE_D` | `(1, 0, 0, 0)` | `1` |
| `FASE_B` | `FASE_C` | `FASE_A` | `(0, 1, 0, 0)` | `2` |
| `FASE_C` | `FASE_D` | `FASE_B` | `(0, 0, 1, 0)` | `3` |
| `FASE_D` | `FASE_A` | `FASE_C` | `(0, 0, 0, 1)` | `4` |

---

## Arquitetura e Arquivos

| Arquivo | Entidade | Função |
| :--- | :--- | :--- |
| [`motor_passo_wave.vhd`](./motor_passo_wave.vhd) | `motor_passo_wave` | FSM de Moore de 4 estados para acionamento em modo wave. |
| [`top_motor_passo.vhd`](./top_motor_passo.vhd) | `top_motor_passo` | Top-level para a DE0-CV: instancia dois divisores (`2 Hz` e `200 Hz`), a FSM, o decodificador `HEX0` e mapeia LEDs e `GPIO_0`. |
| [`divisor_frequencia.vhd`](./divisor_frequencia.vhd) | `divisor_frequencia` | Gera `clk_2hz` (visualização passo a passo nos LEDs) e `clk_200hz` (rotação real do motor 28BYJ-48). |
| [`decod_7seg.vhd`](./decod_7seg.vhd) | `decod_7seg` | Exibe o número da fase ativa (`1` a `4`) em `HEX0`. |
| [`pinos_pratica02.tcl`](./pinos_pratica02.tcl) | — | Script Tcl de atribuição de pinos para a Terasic DE0-CV (`5CEBA4F23C7`). |
| [`top_motor_passo.qpf`](./top_motor_passo.qpf) | — | Projeto do Intel Quartus Prime. |

### Seleção de Velocidade (`SW[1]`) e Simulação
- **`SW[1] = '0'`:** `2 passos/s` (`2 Hz`) — ideal para observar a troca sequencial das fases nos LEDs `LEDR[3..0]` e em `HEX0`.
- **`SW[1] = '1'`:** `200 passos/s` (`200 Hz`) — frequência adequada para girar o motor **28BYJ-48 (5 V)** conectado via driver **ULN2003**.
- **`H_SIMULATION`:** mantenha `0` na placa; use um inteiro $> 0$ (ex.: `4`) em testbench para simulação rápida.

---

## Mapeamento de Pinos (Terasic DE0-CV)

Configurado via [`pinos_pratica02.tcl`](./pinos_pratica02.tcl) (`3.3-V LVTTL`):

| Sinal | Periférico na Placa | Pino(s) FPGA | Função |
| :--- | :--- | :---: | :--- |
| `CLOCK_50` | `CLOCK_50` | `PIN_M9` | Clock principal de 50 MHz |
| `KEY[0]` | `KEY0` | `PIN_U7` | Reset assíncrono ativo em `'0'` (volta para `FASE_A`) |
| `SW[0]` | `SW0` | `PIN_U13` | Sentido (`'0'` = horário, `'1'` = anti-horário) |
| `SW[1]` | `SW1` | `PIN_V13` | Velocidade (`'0'` = 2 Hz, `'1'` = 200 Hz) |
| `LEDR[3..0]` | `LEDR0`–`LEDR3` | `PIN_AA2, AA1, W2, Y3` | Fases `A`, `B`, `C`, `D` (`LEDR[0]=A` .. `LEDR[3]=D`) |
| `LEDR[8]` | `LEDR8` | `PIN_L2` | Indica o sentido selecionado (`SW[0]`) |
| `LEDR[9]` | `LEDR9` | `PIN_L1` | Clock ativo do motor (`clk_motor`) |
| `HEX0[6..0]` | `HEX0` | `PIN_AA22, Y21, Y22, W21, W22, V21, U21` | Número da fase ativa (`1` a `4`) |
| `GPIO_0[3..0]` | Header `GPIO_0` (JP1) | `PIN_C16, M16, B16, N16` | Saídas `A, B, C, D` para `IN1..IN4` do driver ULN2003 (`GPIO_0[0]=A` .. `GPIO_0[3]=D`) |

> [!NOTE]
> Ao ligar o motor de passo **28BYJ-48 (5 V)** através do módulo driver **ULN2003**, alimente o driver com fonte externa de 5 V e conecte o **GND comum** entre a fonte e a placa DE0-CV.

---

## Como Executar no Quartus Prime

1. Abra [`top_motor_passo.qpf`](./top_motor_passo.qpf) no Intel Quartus Prime.
2. Para reaplicar os pinos, execute **Tools → Tcl Scripts... → `pinos_pratica02.tcl` → Run**.
3. Compile o projeto (**Processing → Start Compilation**) e grave o `.sof` na placa DE0-CV via **Programmer**.

# Prática 03 — Gerador de Sinal Assíncrono em Duty Cycle 75% (`2T0` / `6T0`)

Implementação em VHDL de um **gerador de sinal periódico** modelado como Máquina de Estados Finita (FSM) de Moore, desenvolvido para a disciplina **Dispositivos Lógicos Programáveis (DLP)** — **SENAI CIMATEC** (Prof. João Castelo, Unidade 03 — Equipe Giulia).

---

## Descrição da Prática

> **Enunciado (Slide 22 — Prática 03):**
> *Implementar em VHDL um gerador de sinal com uma saída `y` e entrada de clock `clk`, no qual a saída deve permanecer 2 ciclos de clock com nível baixo (`2T0`) e 6 ciclos com nível alto (`6T0`).*

O sinal gerado possui período total de **8 ciclos de clock** ($2 + 6 = 8\cdot T_0$) e **ciclo de trabalho (duty cycle) de 75%** ($\frac{6}{8}$).

---

## Máquina de Estados (`gerador_sinal.vhd`)

- **Estados:** `T0`, `T1`, `T2`, `T3`, `T4`, `T5`, `T6`, `T7` (8 estados sequenciais).
- **Reset (`resetn`):** assíncrono, ativo em nível baixo (`'0'`), retorna ao estado `T0`.
- **Saída (`y`):** Máquina de Moore — depende apenas do estado atual (`'0'` em `T0` e `T1`; `'1'` de `T2` a `T7`).

| Estado Atual | Próximo Estado (`clk` ↑) | Saída `y` | Duração na DE0-CV ($T_0 = 1\text{ s}$) |
| :---: | :---: | :---: | :---: |
| `T0` | `T1` | `'0'` | 1 s (nível baixo) |
| `T1` | `T2` | `'0'` | 1 s (nível baixo — total `2T0` = 2 s) |
| `T2` | `T3` | `'1'` | 1 s (nível alto) |
| `T3` | `T4` | `'1'` | 1 s (nível alto) |
| `T4` | `T5` | `'1'` | 1 s (nível alto) |
| `T5` | `T6` | `'1'` | 1 s (nível alto) |
| `T6` | `T7` | `'1'` | 1 s (nível alto) |
| `T7` | `T0` | `'1'` | 1 s (nível alto — total `6T0` = 6 s) |

---

## Arquitetura e Arquivos

| Arquivo | Entidade | Função |
| :--- | :--- | :--- |
| [`gerador_sinal.vhd`](./gerador_sinal.vhd) | `gerador_sinal` | FSM de Moore de 8 estados que gera `y` (`2T0` em `'0'`, `6T0` em `'1'`). |
| [`top_gerador_sinal.vhd`](./top_gerador_sinal.vhd) | `top_gerador_sinal` | Top-level para a DE0-CV: conecta `divisor_frequencia` (1 Hz), `gerador_sinal` e `decod_7seg`. |
| [`divisor_frequencia.vhd`](./divisor_frequencia.vhd) | `divisor_frequencia` | Divide `CLOCK_50` (50 MHz) para `TARGET_FREQ_HZ = 1` Hz ($T_0 = 1\text{ s}$). |
| [`decod_7seg.vhd`](./decod_7seg.vhd) | `decod_7seg` | Exibe o nível lógico atual de `y` (`0` ou `1`) no display `HEX0`. |
| [`pinos_pratica03.tcl`](./pinos_pratica03.tcl) | — | Script Tcl de atribuição de pinos para a Terasic DE0-CV (`5CEBA4F23C7`). |
| [`top_gerador_sinal.qpf`](./top_gerador_sinal.qpf) | — | Projeto do Intel Quartus Prime. |

### Parâmetro de Simulação (`H_SIMULATION`)
- Em hardware, mantenha `H_SIMULATION => 0` (`1 Hz`, logo `y` permanece `2 s` apagado e `6 s` aceso em `LEDR[0]`).
- Para simulação rápida em testbench/VWF, ajuste `H_SIMULATION` para um inteiro $> 0$ (ex.: `4`).

---

## Mapeamento de Pinos (Terasic DE0-CV)

Configurado via [`pinos_pratica03.tcl`](./pinos_pratica03.tcl) (`3.3-V LVTTL`):

| Sinal | Periférico na Placa | Pino(s) FPGA | Função |
| :--- | :--- | :---: | :--- |
| `CLOCK_50` | `CLOCK_50` | `PIN_M9` | Clock principal de 50 MHz |
| `KEY[0]` | `KEY0` | `PIN_U7` | Reset assíncrono ativo em `'0'` (volta para `T0`) |
| `LEDR[0]` | `LEDR0` | `PIN_AA2` | Saída `y` (2 s apagado, 6 s aceso) |
| `LEDR[9]` | `LEDR9` | `PIN_L1` | Clock lento de 1 Hz (`clk_lento`, período $T_0 = 1\text{ s}$) |
| `HEX0[6..0]` | `HEX0` | `PIN_AA22, Y21, Y22, W21, W22, V21, U21` | Exibe o nível lógico atual de `y` (`0` ou `1`) |

---

## Como Executar no Quartus Prime

1. Abra [`top_gerador_sinal.qpf`](./top_gerador_sinal.qpf) no Intel Quartus Prime.
2. Para reaplicar os pinos, execute **Tools → Tcl Scripts... → `pinos_pratica03.tcl` → Run**.
3. Compile o projeto (**Processing → Start Compilation**) e grave o `.sof` na placa DE0-CV via **Programmer**.

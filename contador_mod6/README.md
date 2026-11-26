# Prática 01 — Contador Módulo 6 (FSM de Moore)

Implementação em VHDL de um **contador módulo 6 (0 a 5)** modelado como Máquina de Estados Finita (FSM) de Moore, desenvolvido para a disciplina **Dispositivos Lógicos Programáveis (DLP)** — **SENAI CIMATEC** (Prof. João Castelo, Unidade 03 — Equipe Giulia).

---

## Descrição da Prática

> **Enunciado (Slide 21 — Prática 01):**
> *Implementar um contador módulo 6 (0 a 5) em VHDL utilizando máquina de estados e gravar na FPGA.*

O circuito avança sequencialmente de `0` a `5` a cada borda de subida do clock e retorna a `0` após `5`. Como se trata de uma **Máquina de Moore**, a saída `q` depende exclusivamente do estado atual.

---

## Máquina de Estados (`contador_mod6.vhd`)

- **Estados:** `S0`, `S1`, `S2`, `S3`, `S4`, `S5`
- **Reset (`resetn`):** assíncrono, ativo em nível baixo (`'0'`), retorna imediatamente para `S0`.

| Estado Atual | Próximo Estado (`clk` ↑) | Saída `q` (Binário) | Valor Decimal (`HEX0`) |
| :---: | :---: | :---: | :---: |
| `S0` | `S1` | `"000"` | `0` |
| `S1` | `S2` | `"001"` | `1` |
| `S2` | `S3` | `"010"` | `2` |
| `S3` | `S4` | `"011"` | `3` |
| `S4` | `S5` | `"100"` | `4` |
| `S5` | `S0` | `"101"` | `5` |

---

## Arquitetura e Arquivos

| Arquivo | Entidade | Função |
| :--- | :--- | :--- |
| [`contador_mod6.vhd`](./contador_mod6.vhd) | `contador_mod6` | FSM de Moore de 6 estados (entidade usada na simulação funcional). |
| [`top_contador_mod6.vhd`](./top_contador_mod6.vhd) | `top_contador_mod6` | Top-level estrutural para a placa DE0-CV: conecta `divisor_frequencia` (1 Hz), `contador_mod6` e `decod_7seg`. |
| [`divisor_frequencia.vhd`](./divisor_frequencia.vhd) | `divisor_frequencia` | Divide `CLOCK_50` (50 MHz) para `TARGET_FREQ_HZ = 1` Hz ($H = 25.000.000$ ciclos por semiciclo). |
| [`decod_7seg.vhd`](./decod_7seg.vhd) | `decod_7seg` | Decodificador hexadecimal para display de 7 segmentos (ânodo comum, ativo em `'0'`). |
| [`pinos_pratica01.tcl`](./pinos_pratica01.tcl) | — | Script Tcl de atribuição de pinos para a Terasic DE0-CV (`5CEBA4F23C7`). |
| [`contador_mod6.qpf`](./contador_mod6.qpf) | — | Projeto do Intel Quartus Prime. |

### Parâmetro de Simulação (`H_SIMULATION`)
- No `top_contador_mod6`, o generic `H_SIMULATION` vem definido como `0` para operação real em hardware (`1 Hz`).
- Para simulação rápida em testbench/VWF sem aguardar milhões de ciclos, sobrescreva `H_SIMULATION` para um inteiro $> 0$ (ex.: `4`).

---

## Mapeamento de Pinos (Terasic DE0-CV)

Configurado via [`pinos_pratica01.tcl`](./pinos_pratica01.tcl) (`3.3-V LVTTL`):

| Sinal | Periférico na Placa | Pino(s) FPGA | Função |
| :--- | :--- | :---: | :--- |
| `CLOCK_50` | `CLOCK_50` | `PIN_M9` | Clock principal de 50 MHz |
| `KEY[0]` | `KEY0` | `PIN_U7` | Reset assíncrono ativo em `'0'` |
| `LEDR[2..0]` | `LEDR0`–`LEDR2` | `PIN_AA2, AA1, W2` | Valor binário atual de `q` (`000` a `101`) |
| `LEDR[9]` | `LEDR9` | `PIN_L1` | Clock lento de 1 Hz (`clk_lento`) |
| `HEX0[6..0]` | `HEX0` | `PIN_AA22, Y21, Y22, W21, W22, V21, U21` | Exibição decimal da contagem (`0` a `5`) |

---

## Como Executar no Quartus Prime

1. Abra [`contador_mod6.qpf`](./contador_mod6.qpf) no Intel Quartus Prime.
2. Defina `top_contador_mod6` como **Top-Level Entity** para gravação na FPGA (ou `contador_mod6` para simulação direta da FSM).
3. Para reaplicar os pinos, execute **Tools → Tcl Scripts... → `pinos_pratica01.tcl` → Run**.
4. Compile o projeto (**Processing → Start Compilation**) e grave o `.sof` na placa DE0-CV via **Programmer**.

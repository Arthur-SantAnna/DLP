# DLP — Dispositivos Lógicos Programáveis

Repositório com os projetos em **VHDL** desenvolvidos para a disciplina **Dispositivos Lógicos Programáveis** do **Centro Universitário SENAI CIMATEC** (Prof. João Castelo), utilizando a placa FPGA **Terasic DE0-CV** (Intel Cyclone V `5CEBA4F23C7N`), **Intel Quartus Prime** e **ModelSim**.

---

## Projetos do Repositório

| Projeto | Unidade / Prática | Descrição | Documentação |
| :--- | :--- | :--- | :---: |
| **Esteira Reversível** | Unidade 02 — Prática Combinacional e Sequencial | Controlador de esteira reversível com divisor de frequência (50 MHz → 2 Hz), contagem limitada (`C = 79`, `L = 60`), registro de pico, detecção de erro e exibição em dois displays de 7 segmentos. | [`esteira_reversivel/README.md`](./esteira_reversivel/README.md) |
| **Contador Módulo 6** | Unidade 03 — Prática 01 (FSM) | Contador síncrono módulo 6 (`0` a `5`) implementado como Máquina de Moore (`S0`–`S5`), com divisor de 1 Hz e exibição em LEDs e `HEX0`. | [`contador_mod6/README.md`](./contador_mod6/README.md) |
| **Motor de Passo (Modo Wave)** | Unidade 03 — Prática 02 (FSM) | Controlador de motor de passo unipolar (28BYJ-48 + driver ULN2003) em modo *wave* como Máquina de Moore (`FASE_A`–`FASE_D`), com seleção de sentido (`SW[0]`) e velocidade (2 Hz / 200 Hz via `SW[1]`). | [`motor_passo_wave/README.md`](./motor_passo_wave/README.md) |
| **Gerador de Sinal (`2T0` / `6T0`)** | Unidade 03 — Prática 03 (FSM) | Gerador de onda periódica com nível baixo por `2T0` e nível alto por `6T0` (*duty cycle* de 75%) modelado como Máquina de Moore de 8 estados (`T0`–`T7`). | [`gerador_sinal/README.md`](./gerador_sinal/README.md) |
| **Controlador de Acesso RFID** | Unidade 03 — Prática Extra (FSM) | Sistema de controle de acesso via cartões RFID (RC522 via SPI) gerenciado por Máquina de Moore (`S_AGUARDANDO`, `S_LENDO`, `S_VERIFICANDO`, `S_AUTORIZADO`, `S_NEGADO`, `S_BLOQUEADO`), com cadastro dinâmico e feedback em LEDs e displays. | [`controlador_rfid/README.md`](./controlador_rfid/README.md) |

---

## Estrutura Geral

```text
DLP/
├── .gitignore              # Regras globais para ignorar artefatos do Quartus/ModelSim
├── LICENSE
├── README.md
├── esteira_reversivel/     # Prática da esteira reversível (Unidade 02)
├── contador_mod6/          # Prática 01 - Contador módulo 6 (Unidade 03)
├── motor_passo_wave/       # Prática 02 - Motor de passo modo wave (Unidade 03)
├── gerador_sinal/          # Prática 03 - Gerador de sinal 2T0/6T0 (Unidade 03)
└── controlador_rfid/       # Prática Extra - Controle de acesso RFID (Unidade 03)
```

---

## Ferramentas e Hardware

- **Placa FPGA:** Terasic DE0-CV (Cyclone V `5CEBA4F23C7N`, clock de `50 MHz`)
- **Síntese e Pinagem:** Intel Quartus Prime (scripts `.tcl` inclusos em cada projeto)
- **Simulação:** ModelSim e Quartus Vector Waveform (`.vwf`)

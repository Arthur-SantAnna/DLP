# Sistema de Controle de Acesso com RFID e Estados de Autorização

**Disciplina:** Dispositivos Lógicos Programáveis (DLP) — Prof. João Castelo (SENAI CIMATEC)  
**Placa FPGA Alvo:** Terasic DE0-CV — Altera/Intel Cyclone V (`5CEBA4F23C7`)  
**Leitor RFID Externo:** Módulo MFRC522 (RFID-RC522 13.56 MHz via SPI 3.3V)

---

## 1. Escolha e Justificativa da Máquina de Estados: Moore vs. Mealy

Conforme apresentado nos slides 4 a 19 da aula de *Máquina de Estados Finita (FSM)*:
- **$T$ (Função de próximo estado)**: Lógica combinacional que recebe o estado atual e as entradas para definir o próximo estado.
- **$S$ (Elemento de memória)**: Registrador de estado (Flip-Flops sincronizados pela borda de subida do clock).
- **$G$ (Função de saída)**: Lógica combinacional que calcula as saídas a partir do estado atual (**Moore**) ou do estado atual e das entradas (**Mealy**).

### Por que escolhemos a **Máquina de Moore** (`access_control_fsm.vhd`)?
1. **Estabilidade e Segurança no Acionamento Físico (Sem *Glitches*)**:
   - No controle de uma trava elétrica/solenoide (`LOCK_ACTUATOR`) e de sinalizadores visuais (`LEDR` e displays `HEX5..HEX0`), a saída **não pode sofrer oscilações assíncronas** causadas por ruídos na linha SPI do leitor RFID ou *bouncing* de chaves.
   - Como na Máquina de Moore a saída depende **exclusivamente do estado atual**, todas as saídas mudam apenas de forma síncrona à borda do clock (slide 5 do PDF).
2. **Papel do Divisor de Frequência (`divisor_frequencia.vhd`)**:
   - Como o clock natural da placa DE0-CV é de **50 MHz** (20 ns), utilizamos o módulo `divisor_frequencia.vhd` (no mesmo padrão da prática da Esteira) para gerar um sinal dividido de **2 Hz** (`sinal_div`, visível piscando no `LEDR[7]`) e um pulso de avanço (`pulso_avanco`, a cada 0,5s).
   - As transições temporizadas da Máquina de Moore (`S_LENDO` $\rightarrow$ `S_VERIFICANDO` $\rightarrow$ `S_AUTORIZADO` / `S_NEGADO` / `S_BLOQUEADO`) avançam sincronizadas pelo `pulso_avanco`, permitindo visualizar cada estado perfeitamente nos displays de 7 segmentos na placa (com `H_SIMULATION = 0`) e em poucos nanossegundos no ModelSim (com `H_SIMULATION = 2` ou `4`).

| Estado Atual (`estado`) | Código (`state_code`) | Duração (`pulso_avanco` @ 2Hz) | `trava_aberta` | `led_autorizado` (`LEDR[9]`) | `led_negado` (`LEDR[8]`) | `led_bloqueado` (`LEDR[6]`) | Mensagem no Display (`HEX3..HEX0`) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`S_AGUARDANDO`** | `"000"` | Até ler cartão | `'0'` | `'0'` | `'0'` | `'0'` | **`idLE`** |
| **`S_LENDO`** | `"001"` | 1 pulso (0,5s) | `'0'` | `'0'` | `'0'` | `'0'` | **`rEAd`** |
| **`S_VERIFICANDO`** | `"010"` | 1 pulso (0,5s) | `'0'` | `'0'` | `'0'` | `'0'` | **`ChEC`** |
| **`S_AUTORIZADO`** | `"011"` | 6 pulsos (3,0s) | **`'1'`** | **`'1'`** | `'0'` | `'0'` | **`OPEn`** |
| **`S_NEGADO`** | `"100"` | 4 pulsos (2,0s) | `'0'` | `'0'` | **`'1'`** | `'0'` | **`ErrO`** |
| **`S_BLOQUEADO`** | `"101"` | 10 pulsos (5,0s) | `'0'` | `'0'` | **`'1'`** | **`'1'`** | **`LOCd`** |

---

## 2. Esquema de Ligação do Módulo RFID-RC522 na Placa DE0-CV (`GPIO_0` / JP1)

> **ATENÇÃO:** O módulo RFID-RC522 deve ser alimentado em **3.3V** (**Pino 29 do header JP1**). **Nunca** ligue no pino 11 (5V), pois isso pode queimar o RC522.

| Pino no Módulo RFID-RC522 | Sinal no VHDL | Pino do Chip FPGA (`5CEBA4F23C7`) | Pino Físico no Conector `GPIO_0` (JP1) | Função |
| :--- | :--- | :---: | :---: | :--- |
| **SDA (NSS / CS)** | `RC522_CS_N` | `PIN_N16` | **Pino 1** (Canto superior esquerdo) | Chip Select SPI (Ativo Baixo) |
| **SCK** | `RC522_SCK` | `PIN_B16` | **Pino 2** (Canto superior direito) | Clock SPI (~1.56 MHz) |
| **MOSI** | `RC522_MOSI` | `PIN_M16` | **Pino 3** | Master Out Slave In |
| **MISO** | `RC522_MISO` | `PIN_C16` | **Pino 4** | Master In Slave Out |
| **IRQ** | *(Desconectado)* | — | — | Não utilizado |
| **GND** | `GND` | — | **Pino 12** ou **Pino 30** | Terra Comum (GND) |
| **RST** | `RC522_RST_N` | `PIN_D17` | **Pino 5** | Reset / Power-Down do RC522 |
| **3.3V** | `VCC3P3` | — | **Pino 29** | Alimentação 3.3V da Placa |
| *(Relé / Atuador)* | `LOCK_ACTUATOR` | `PIN_K20` | **Pino 6** | Saída Digital 3.3V de Trava Aberta |

---

## 3. Como Operar na Placa FPGA durante a Demonstração

### Controles (Chaves e Botões)
- **`RESET_N` (`PIN_P22`) ou `KEY[0]` (`PIN_U7`)**: Reset geral da máquina de estados (retorna imediatamente para `S_AGUARDANDO` / `idLE` e zera falhas).
- **`SW[9]` (`PIN_AB12`) — Seleção de Modo de Operação**:
  - **`SW[9] = '0'` (Modo Leitor RFID-RC522 Real)**: Lê automaticamente qualquer cartão ou chaveiro RFID de 13.56 MHz aproximado da antena do RC522.
  - **`SW[9] = '1'` (Modo Simulação / Chaves Manuais)**: Usa o byte configurado nas chaves `SW[7:0]` como ID do cartão quando você aperta **`KEY[1]` (`PIN_W9`)**.
    - Cartões pré-cadastrados na ROM para teste rápido:
      - `SW[7:0] = "10100101"` (`0xA5`) $\rightarrow$ **Autorizado (`OPEn`)**
      - `SW[7:0] = "00111100"` (`0x3C`) $\rightarrow$ **Autorizado (`OPEn`)**
      - Qualquer outro valor (ex: `0x01`) $\rightarrow$ **Negado (`ErrO`)**; 3 vezes seguidas $\rightarrow$ **Bloqueado (`LOCd`)**
- **`SW[8]` (`PIN_AB13`) — Visualizador de UID Completo**:
  - **`SW[8] = '0'`**: Os displays mostram o byte final do cartão em `HEX5..HEX4` e a palavra de status (`idLE`, `rEAd`, `ChEC`, `OPEn`, `ErrO`, `LOCd`) em `HEX3..HEX0`.
  - **`SW[8] = '1'`**: Os 6 displays (`HEX5..HEX0`) exibem em hexadecimal os 24 bits inferiores do UID do último cartão lido pelo RC522.
- **`KEY[2]` (`PIN_M7`) — Cadastrar Cartão RFID na Hora!**:
  - Aproxime o cartão do leitor RC522 e aperte **`KEY[2]`**. O LED `LEDR[5]` acenderá indicando que o UID desse cartão foi salvo como autorizado! Na próxima aproximação, ele exibirá **`OPEn`**.
- **`KEY[3]` (`PIN_M6`) — Remover Cartão Cadastrado**:
  - Apaga o cartão salvo dinamicamente (`LEDR[5]` apaga).

---

## 4. Como Compilar, Mapear Pinos, Simular e Gravar

1. **Abrir Projeto**: Abra `RFIDSystem.qpf` no Quartus Prime / Quartus II.
2. **Mapeamento de Pinos**: Já está salvo no `RFIDSystem.qsf`, ou você pode rodar o script `mapeamento_pinos.tcl` em *Tools $\rightarrow$ Tcl Scripts...* (exatamente como na prática da Esteira).
3. **Simular no ModelSim**: Copie e cole os comandos do arquivo `comandos_testbench_modelsim.txt` no console *Transcript* do ModelSim.
4. **Gravar na Placa**: Em `rfid_access_top.vhd`, o generic `H_SIMULATION` já está em `0` por padrão (modo Hardware 50 MHz $\rightarrow$ 2 Hz). Basta compilar e gravar `output_files/RFIDSystem.sof` pelo *Programmer*.

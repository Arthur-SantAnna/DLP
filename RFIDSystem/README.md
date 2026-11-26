# Sistema de Controle de Acesso com RFID e Estados de Autorização

**Disciplina:** Dispositivos Lógicos Programáveis (DLP) — Prof. João Castelo (SENAI CIMATEC)  
**Placa FPGA Alvo:** Terasic DE0-CV — Altera/Intel Cyclone V (`5CEBA4F23C7`)  
**Leitor RFID Externo:** Módulo MFRC522 (RFID-RC522 13.56 MHz — ISO/IEC 14443A via SPI 3.3V)

---

## 1. Visão Geral e Arquitetura dos Módulos VHDL

O sistema implementa em hardware (VHDL) um controlador completo de acesso por rádio-frequência (RFID 13.56 MHz) integrado aos periféricos da placa **Terasic DE0-CV** (displays de 7 segmentos `HEX5..HEX0`, LEDs `LEDR[9:0]`, chaves `SW[9:0]` e botões `KEY[3:0]`).

| Arquivo | Função no Sistema |
| :--- | :--- |
| **`rfid_access_pkg.vhd`** | Pacote com tipos da FSM de Moore, códigos dos displays, ROM de cartões pré-autorizados (`AUTHORIZED_UIDS`) e endereços/comandos internos do chip MFRC522. |
| **`divisor_frequencia.vhd`** | Divide o clock de **50 MHz** da DE0-CV para **2 Hz** (`sinal_div`, visível em `LEDR[7]`), gerando pulsos síncronos (`pulso_avanco` a cada 0,5 s) para cadenciar as transições visuais da FSM. |
| **`spi_master.vhd`** | Transceptor SPI Master Modo 0 (`CPOL=0, CPHA=0`) a **1,5625 MHz** (`50 MHz / 32`), com sincronizador duplo no pino `MISO`. |
| **`rc522_controller.vhd`** | Micro-FSM dedicada que inicializa o MFRC522 (*Hardware Reset*, *Soft Reset* com espera de 50 ms, configuração de timer, ganho RX máximo de 48 dB e ativação da antena), lê o `VersionReg` (`0x37`) para diagnóstico SPI e realiza *polling* ISO14443A (`REQA` + `ANTICOLLISION` CL1) a cada 50 ms, extraindo os 32 bits do UID e validando o byte `BCC` (XOR). |
| **`access_control_fsm.vhd`** | Máquina de Estados Finita de **Moore** que controla a autorização, o contador de falhas consecutivas (bloqueio na 3ª tentativa inválida) e o banco de **até 4 cartões cadastrados dinamicamente** via `KEY[2]`. |
| **`hex_display_decoder.vhd`** | Decodificador para os 6 displays de 7 segmentos (ânodo comum / ativo baixo), exibindo as mensagens de estado (`idLE`, `rEAd`, `ChEC`, `OPEn`, `ErrO`, `LOCd`), o byte final do UID, o UID hexadecimal de 24 bits ou a versão SPI do RC522 (`----XX`). |
| **`rfid_access_top.vhd`** | Entidade *Top-Level* do Quartus Prime que interliga todos os módulos aos pinos físicos da FPGA Cyclone V. |
| **`tb_rfid_access.vhd`** | Testbench de validação funcional no ModelSim (`H_SIMULATION = 2`). |

---

## 2. Escolha e Justificativa da Máquina de Estados: Moore vs. Mealy

Conforme os conceitos de *Máquina de Estados Finita (FSM)* da disciplina:
- **$T$ (Função de próximo estado)**: lógica combinacional que recebe o estado atual e as entradas para definir o próximo estado.
- **$S$ (Elemento de memória)**: registrador de estado (Flip-Flops sincronizados pela borda de subida do clock).
- **$G$ (Função de saída)**: lógica combinacional que calcula as saídas a partir do estado atual (**Moore**) ou do estado atual e das entradas (**Mealy**).

### Por que escolhemos a **Máquina de Moore** (`access_control_fsm.vhd`)?
1. **Estabilidade e Ausência de *Glitches* nas Saídas**:
   - No acionamento da indicação de trava aberta (`LEDR[9]`), alarme de bloqueio (`LEDR[6]`) e mensagens nos displays (`HEX5..HEX0`), a saída **não pode sofrer oscilações assíncronas** causadas por ruídos na linha SPI do leitor RFID ou *bouncing* de chaves.
   - Como na Máquina de Moore a saída depende **exclusivamente do estado atual**, todas as saídas mudam apenas de forma síncrona ao clock.
2. **Integração com o Divisor de Frequência (`divisor_frequencia.vhd`)**:
   - A detecção inicial do cartão em `S_AGUARDANDO` ocorre imediatamente no domínio de **50 MHz** para não perder o pulso de leitura do RC522 ou botão.
   - As transições temporizadas (`S_LENDO` $\rightarrow$ `S_VERIFICANDO` $\rightarrow$ `S_AUTORIZADO` / `S_NEGADO` / `S_BLOQUEADO`) avançam sincronizadas pelo `pulso_avanco` de **2 Hz** (0,5 s por pulso), permitindo acompanhar cada estado claramente nos displays da placa (`H_SIMULATION = 0`) e simular todo o fluxo em poucos nanossegundos no ModelSim (`H_SIMULATION = 2`).

| Estado Atual (`estado`) | Código (`LEDR[2:0]`) | Duração (`pulso_avanco` @ 2 Hz) | `led_autorizado` (`LEDR[9]`) | `led_negado` (`LEDR[8]`) | `led_bloqueado` (`LEDR[6]`) | Mensagem no Display (`HEX3..HEX0`) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **`S_AGUARDANDO`** | `"000"` | Até ler cartão | `'0'` | `'0'` | `'0'` | **`idLE`** |
| **`S_LENDO`** | `"001"` | 1 pulso (0,5 s) | `'0'` | `'0'` | `'0'` | **`rEAd`** |
| **`S_VERIFICANDO`** | `"010"` | 1 pulso (0,5 s) | `'0'` | `'0'` | `'0'` | **`ChEC`** |
| **`S_AUTORIZADO`** | `"011"` | 6 pulsos (3,0 s) | **`'1'`** | `'0'` | `'0'` | **`OPEn`** |
| **`S_NEGADO`** | `"100"` | 4 pulsos (2,0 s) | `'0'` | **`'1'`** | `'0'` | **`ErrO`** |
| **`S_BLOQUEADO`** | `"101"` | 10 pulsos (5,0 s) | `'0'` | **`'1'`** | **`'1'`** | **`LOCd`** |

---

## 3. Esquema de Ligação do Módulo RFID-RC522 na Placa DE0-CV (`GPIO_0` / `JP1`)

> **ATENÇÃO MÁXIMA:** O módulo RFID-RC522 deve ser alimentado exclusivamente em **3.3V** (**Pino 29 do header `JP1`**). **Nunca** ligue no Pino 11 (`5V`), pois isso pode queimar o chip MFRC522. Certifique-se também de conectar no header **`JP1` (`GPIO_0`)** e não no `JP2` (`GPIO_1`).

| Pino no Módulo RFID-RC522 | Sinal no VHDL | Pino do Chip FPGA (`5CEBA4F23C7`) | Pino Físico no Conector `GPIO_0` (`JP1`) | Função |
| :--- | :--- | :---: | :--- | :--- |
| **SDA (NSS / CS)** | `RC522_CS_N` | `PIN_N16` | **Pino 1** (`GPIO_0[0]`) | Chip Select SPI (Ativo Baixo) |
| **SCK** | `RC522_SCK` | `PIN_B16` | **Pino 2** (`GPIO_0[1]`) | Clock SPI (1,5625 MHz) |
| **MOSI** | `RC522_MOSI` | `PIN_M16` | **Pino 3** (`GPIO_0[2]`) | Master Out Slave In |
| **MISO** | `RC522_MISO` | `PIN_C16` | **Pino 4** (`GPIO_0[3]`) | Master In Slave Out (Pull-Up interno ativo) |
| **IRQ** | *(Desconectado)* | — | *(Sem fio)* | Não utilizado (leitura via *polling* SPI a cada 50 ms) |
| **GND** | `GND` | — | **Pino 12** ou **Pino 30** | Terra Comum (`GND`) |
| **RST** | `RC522_RST_N` | `PIN_D17` | **Pino 5** (`GPIO_0[4]`) | Reset de Hardware do RC522 |
| **3.3V** | `VCC3P3` | — | **Pino 29** | Alimentação **3.3V** da Placa |

### Disposição Física das Fileiras no Conector `JP1` (`GPIO_0` — 40 pinos)
Localize a marcação do **Pino 1** no canto do conector `JP1`:

```text
   Fileira ÍMPAR                      Fileira PAR
  [  1 ]  <- SDA (RC522_CS_N)        [  2 ]  <- SCK  (RC522_SCK)
  [  3 ]  <- MOSI (RC522_MOSI)       [  4 ]  <- MISO (RC522_MISO)
  [  5 ]  <- RST (RC522_RST_N)       [  6 ]
  [  7 ]                             [  8 ]
  [  9 ]                             [ 10 ]
  [ 11 ]  (5V - NÃO LIGAR!)          [ 12 ]  <- GND (pode usar o 12 ou o 30)
   ...                                ...
  [ 29 ]  <- 3.3V (Alimentação)      [ 30 ]  <- GND
   ...                                ...
  [ 39 ]                             [ 40 ]
```

---

## 4. Mapa de Controles, LEDs e Displays na DE0-CV

### Botões (`KEY[3:0]` e `RESET_N` — Ativos em Nível Baixo `'0'`)
- **`RESET_N` (`PIN_P22`) ou `KEY[0]` (`PIN_U7`)**: Reset geral (volta imediatamente para `S_AGUARDANDO` / `00 idLE`, zera contador de falhas e limpa os cartões dinâmicos).
- **`KEY[1]` (`PIN_W9`)**: Dispara uma leitura manual usando o byte configurado em `SW[7:0]` (útil para testar a FSM pelas chaves).
- **`KEY[2]` (`PIN_M7`)**: **Cadastra o último cartão lido** em um dos **4 slots dinâmicos** (ignora duplicatas se o mesmo cartão já estiver salvo).
- **`KEY[3]` (`PIN_M6`)**: **Remove todos os cartões cadastrados dinamicamente** (limpa os 4 slots).

### Chaves (`SW[9:0]`)
- **`SW[9]` (`PIN_AB12`) — Seleção de Modo de Operação**:
  - **`SW[9] = '0'` (Modo Leitor RFID-RC522 Real)**: Lê automaticamente qualquer cartão ou chaveiro RFID 13.56 MHz aproximado da antena do RC522.
  - **`SW[9] = '1'` (Modo Simulação / Chaves Manuais)**: Lê o byte definido em `SW[7:0]` ao pressionar `KEY[1]`.
    - Cartões pré-gravados na ROM (`AUTHORIZED_UIDS`):
      - `SW[7:0] = "10100101"` (`0xA5`) $\rightarrow$ **Autorizado (`OPEn`)**
      - `SW[7:0] = "00111100"` (`0x3C`) $\rightarrow$ **Autorizado (`OPEn`)**
      - Qualquer outro valor (ex.: `0x05`) $\rightarrow$ **Negado (`ErrO`)**; 3 vezes seguidas $\rightarrow$ **Bloqueado (`LOCd`)**
- **`SW[8]` (`PIN_AB13`) — Visualizador de UID / Diagnóstico SPI**:
  - **`SW[8] = '0'` (Modo Padrão)**: `HEX5..HEX4` exibem o byte final (`uid[7:0]`) do último cartão lido e `HEX3..HEX0` exibem o estado (`idLE`, `rEAd`, `ChEC`, `OPEn`, `ErrO`, `LOCd`).
  - **`SW[8] = '1'` (Modo Inspeção)**:
    - Se nenhum cartão foi lido ainda (`UID = 0`), exibe **`----XX`**, onde `XX` é o registrador `VersionReg` (`0x37`) lido do RC522 via SPI (`91`, `92`, `88` ou `B2` confirma comunicação SPI OK; `FF` ou `00` indica falha física nos fios SPI).
    - Após ler um cartão, exibe nos 6 displays (`HEX5..HEX0`) os 24 bits inferiores do UID em hexadecimal.

### LEDs (`LEDR[9:0]`)
| LED | Sinal | Significado |
| :---: | :--- | :--- |
| **`LEDR[9]`** | `led_autorizado` | **Acesso Autorizado / Trava Aberta** (aceso por 3,0 s durante `OPEn`) |
| **`LEDR[8]`** | `led_negado` | **Acesso Negado** (aceso em `ErrO` e `LOCd`) |
| **`LEDR[7]`** | `sig_sinal_div` | **Clock Dividido (2 Hz)** — pisca continuamente indicando que o divisor de frequência está ativo |
| **`LEDR[6]`** | `led_bloqueado` | **Alarme de Bloqueio** (aceso por 5,0 s após 3 tentativas inválidas seguidas — `LOCd`) |
| **`LEDR[5]`** | `enrolled_active` | **Cartão Dinâmico Ativo** (aceso quando há de 1 a 4 cartões cadastrados via `KEY[2]`) |
| **`LEDR[4:3]`** | `fail_count` | **Contador Binário de Erros Consecutivos** (`00` = 0, `01` = 1 erro, `10` = 2 erros, `11` = 3 erros/bloqueado) |
| **`LEDR[2:0]`** | `state_code` | **Código Binário do Estado Atual da FSM de Moore** (`000` a `101`) |

---

## 5. Roteiro Passo a Passo para Demonstração na Bancada

1. **Estado Inicial (`idLE`)**:
   - Com todas as chaves `SW[9:0]` para baixo (`'0'`), mostre o display exibindo `00 idLE` e o `LEDR[7]` piscando a 2 Hz.
   - *(Opcional)* Suba `SW[8]` para mostrar a versão do chip RC522 (`----92` / `----91`), comprovando a comunicação SPI, e volte `SW[8]` para baixo.
2. **Tentativa com Cartão Não Cadastrado e Bloqueio (`ErrO` $\rightarrow$ `LOCd`)**:
   - Aproxime um cartão não cadastrado: o display mostra o byte final do cartão (ex.: `56`) e passa por `rEAd` $\rightarrow$ `ChEC` $\rightarrow$ `ErrO`, acendendo `LEDR[8]` e incrementando `LEDR[4:3]` para `01`.
   - Passe mais duas vezes seguidas: na 2ª vez `LEDR[4:3]` vai para `10`; na 3ª vez o sistema entra em **`LOCd`** por 5 segundos com `LEDR[6]` e `LEDR[8]` acesos, retornando depois automaticamente para `idLE` com o contador zerado.
3. **Cadastro Dinâmico de Múltiplos Cartões (`KEY[2]`) e Liberação (`OPEn`)**:
   - Após passar o **Cartão 1**, pressione **`KEY[2]`**: o `LEDR[5]` acende.
   - Passe o **Cartão 1** novamente: o sistema passa por `rEAd` $\rightarrow$ `ChEC` $\rightarrow$ **`OPEn`** por 3 segundos e acende o **`LEDR[9]`** (Trava Aberta).
   - Passe um **Cartão 2** diferente (dará `ErrO` na 1ª leitura) e pressione **`KEY[2]`**: agora **tanto o Cartão 1 quanto o Cartão 2** (e até 4 cartões no total) estão autorizados e abrem a trava (`OPEn` + `LEDR[9]`).
4. **Remoção de Cadastro (`KEY[3]`)**:
   - Pressione **`KEY[3]`**: o `LEDR[5]` apaga e os cartões voltam a ser negados (`ErrO`).

---

## 6. Como Compilar, Mapear Pinos, Simular e Gravar

1. **Abrir o Projeto no Quartus**: abra `RFIDSystem.qpf` no Quartus Prime.
2. **Mapeamento de Pinos**: já está configurado no `RFIDSystem.qsf` (ou pode ser reaplicado em *Tools $\rightarrow$ Tcl Scripts...* executando `mapeamento_pinos.tcl`).
3. **Simular no ModelSim**: copie os comandos de `comandos_testbench_modelsim.txt` e cole no console *Transcript* do ModelSim-Altera.
4. **Compilar e Gravar na DE0-CV**:
   - Em `rfid_access_top.vhd`, o generic `H_SIMULATION` já está em `0` por padrão (modo hardware 50 MHz $\rightarrow$ 2 Hz).
   - Execute **Compile Design** e grave `output_files/RFIDSystem.sof` via *Tools $\rightarrow$ Programmer* usando o **USB-Blaster**.

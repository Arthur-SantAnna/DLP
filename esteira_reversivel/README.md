# Esteira Reversível com Divisor de Frequência

Controlador digital em VHDL para uma esteira reversível didática que coloca ou retira peças de uma bandeja, desenvolvido para a disciplina **Dispositivos Lógicos Programáveis (DLP)** — **SENAI CIMATEC** (Prof. João Castelo).

O projeto implementa um divisor de frequência a partir do clock de 50 MHz da FPGA, contagem limitada com detecção de transbordo/subfluxo, registro de pico de ocupação, indicadores de estado em LEDs e multiplexação de exibição em dois displays de 7 segmentos.

---

## Parâmetros da Equipe

| Parâmetro | Símbolo / Generic | Valor Implementado | Descrição |
| :--- | :--- | :---: | :--- |
| Capacidade máxima da bandeja | `C_CAPACIDADE` | **79** | Quantidade máxima de peças ($20 \le C \le 79$) |
| Limiar de alerta | `L_LIMIAR` | **60** | Nível de ocupação para acionar `alerta` ($1 \le L < C$) |
| Clock de entrada | `CLOCK_IN_HZ` | **50 MHz** | Clock da placa DE0-CV (período de 20 ns) |
| Frequência de avanço | `TARGET_FREQ_HZ` | **2 Hz** | Ritmo de tentativas de movimentação (2 peças/s) |

---

## Divisor de Frequência e Cálculo dos Parâmetros

O módulo [`divisor_frequencia.vhd`](./divisor_frequencia.vhd) gera uma onda quadrada `sinal_div` com ciclo de trabalho de 50% na frequência $F = 2\text{ Hz}$ e um pulso síncrono `pulso_avanco` de duração igual a um ciclo de `clk_50` (20 ns) a cada borda de subida de `sinal_div`.

### Cálculo para Hardware (50 MHz → 2 Hz)
- **Ciclos por semiciclo ($H$):**
  $$H = \frac{f_{\text{clk}}}{2 \cdot F} = \frac{50.000.000}{2 \cdot 2} = 12.500.000\text{ ciclos}$$
- **Valor terminal do contador (`cnt`):** de `0` até `12.499.999` (`CYCLES_PER_HALF_PERIOD - 1`).
- **Largura mínima de bits do contador:** **24 bits**, pois $2^{23} = 8.388.608 < 12.500.000 \le 16.777.216 = 2^{24}$.
- **Intervalo de inversão vs. Período completo:**
  - `sinal_div` inverte a cada semiciclo ($12.500.000 \times 20\text{ ns} = 0{,}25\text{ s}$).
  - O período completo corresponde a dois semiciclos ($25.000.000 \times 20\text{ ns} = 0{,}5\text{ s}$, equivalente a $2\text{ Hz}$).
  - Após `rst = '1'` ou retomada de `pausa = '1'`, `sinal_div` inicia em `'0'`, ocorrendo a primeira borda de subida após $0{,}25\text{ s}$ e as seguintes a cada $0{,}5\text{ s}$.

### Latência e Simulação Acelerada
- **Latência do avanço:** `pulso_avanco` é registrado na borda de `clk_50` em que `sinal_div` sobe de `'0'` para `'1'`. O núcleo sequencial em `dlp_projeto.vhd` amostra `sig_pulso_avanco = '1'` na borda de subida seguinte de `clk_50` (latência de **1 ciclo de clock / 20 ns** após a borda de subida de `sinal_div`).
- **Parâmetro `H_SIMULATION`:**
  - Para **síntese na FPGA**, mantenha `H_SIMULATION => 0` (usa automaticamente `12.500.000`).
  - Para **simulação funcional** (ModelSim / `.vwf`), altere `H_SIMULATION` para um inteiro $\ge 2$ (ex.: `4` ou `5`) para acelerar a simulação mantendo `clk_50` em 20 ns e a mesma lógica de pausa.

---

## Arquitetura do Projeto

O sistema está organizado em blocos estruturais e comportamentais identificáveis no RTL:

| Arquivo | Entidade | Função |
| :--- | :--- | :--- |
| [`dlp_projeto.vhd`](./dlp_projeto.vhd) | `dlp_projeto` | Top-level estrutural: instancia os submódulos, implementa o núcleo sequencial (`reg_N`, `reg_P`, `reg_erro`), os indicadores combinacionais e a separação decimal (`dezena` / `unidade`). |
| [`divisor_frequencia.vhd`](./divisor_frequencia.vhd) | `divisor_frequencia` | Divisor síncrono sintetizável de 50 MHz para 2 Hz com suporte a `rst` assíncrono, `pausa` síncrona e generic `H_SIMULATION`. |
| [`seletor_exibicao.vhd`](./seletor_exibicao.vhd) | `seletor_exibicao` | Multiplexador combinacional dos 4 modos de exibição. Contém implementações equivalentes com `with ... select` (ativa) e `when ... else` (comentada para comparação). |
| [`decodificador_7seg.vhd`](./decodificador_7seg.vhd) | `decodificador_7seg` | Decodificador BCD para display de 7 segmentos (ânodo comum, ativo em `'0'`). Apaga todos os segmentos (`"1111111"`) para códigos inválidos de 10 a 15. |

---

## Regras de Funcionamento

1. **Prioridade de `rst` e `pausa`:**
   - `rst = '1'` é **assíncrono** e prioritário sobre qualquer entrada: zera `reg_N`, `reg_P`, `reg_erro`, o contador do divisor, `sinal_div` e `pulso_avanco`.
   - Fora do reset, `pausa = '1'` tem prioridade sobre `pulso_avanco`: preserva `reg_N`, `reg_P` e `reg_erro` e reinicia a fase do divisor (`cnt <= 0`, `sinal_div <= '0'`, `pulso_avanco <= '0'`), descartando avanços pendentes.
2. **Atualização da Contagem (`N`), Pico (`P`) e Erro (`erro`):**

| Condição (`clk_50` ↑) | Resultado para `N` | Resultado para `P` | Resultado para `erro` |
| :--- | :--- | :--- | :--- |
| `pausa = '1'` | Mantém `N` | Mantém `P` | Mantém `erro` |
| `pausa = '0'` e `pulso_avanco = '0'` | Mantém `N` | Mantém `P` | Mantém `erro` |
| Pulso; `sentido = '0'`; `N < C` | `N <= N + 1` | Se `N + 1 > P`, `P <= N + 1` | Mantém `erro` |
| Pulso; `sentido = '0'`; `N = C` | Permanece em `C` | Mantém `P` | `erro <= '1'` |
| Pulso; `sentido = '1'`; `N > 0` | `N <= N - 1` | Mantém `P` | Mantém `erro` |
| Pulso; `sentido = '1'`; `N = 0` | Permanece em `0` | Mantém `P` | `erro <= '1'` |

3. **Indicadores Combinacionais:**
   - `cheio <= '1'` quando `N = C` (`79`)
   - `vazio <= '1'` quando `N = 0`
   - `alerta <= '1'` quando `N >= L` (`60`)
   - `erro` permanece travado em `'1'` até o próximo `rst = '1'`.

4. **Modos de Exibição nos Displays (`modo`):**

| `modo` | Valor Exibido (`hex1` `hex0`) | Após `rst` |
| :---: | :--- | :---: |
| `"00"` | Quantidade atual de peças (`N`) | `00` |
| `"01"` | Espaços disponíveis (`C - N`) | `79` |
| `"10"` | Pico máximo atingido desde o último reset (`P`) | `00` |
| `"11"` | Capacidade máxima da bandeja (`C`) | `79` |

---

## Mapeamento de Pinos (Terasic DE0-CV — Cyclone V `5CEBA4F23C7N`)

O script [`mapeamento_pinos.tcl`](./mapeamento_pinos.tcl) configura automaticamente toda a pinagem no Quartus Prime (padrão `3.3-V LVTTL`):

### Entradas e Controle
| Sinal | Periférico na Placa | Pino FPGA | Função |
| :--- | :--- | :---: | :--- |
| `clk_50` | `CLOCK_50` | `PIN_M9` | Clock principal de 50 MHz |
| `rst` | `SW9` | `PIN_AB12` | Reset assíncrono ativo em `'1'` |
| `sentido` | `SW0` | `PIN_U13` | `'0'`: colocar peças / `'1'`: retirar peças |
| `pausa` | `SW1` | `PIN_V13` | `'1'`: pausa contagem e reinicia fase do divisor |
| `modo[0]` | `SW2` | `PIN_T13` | Bit 0 do seletor de exibição |
| `modo[1]` | `SW3` | `PIN_T12` | Bit 1 do seletor de exibição |

### Saídas (LEDs e Displays)
| Sinal | Periférico na Placa | Pino(s) FPGA | Descrição |
| :--- | :--- | :---: | :--- |
| `pulso_avanco` | `LEDR0` | `PIN_AA2` | Pulso de 20 ns a cada avanço |
| `sinal_div` | `LEDR1` | `PIN_AA1` | Onda quadrada dividida (pisca a 2 Hz) |
| `cheio` | `LEDR2` | `PIN_W2` | Indica `N = 79` |
| `vazio` | `LEDR3` | `PIN_Y3` | Indica `N = 0` |
| `alerta` | `LEDR4` | `PIN_N2` | Indica `N >= 60` |
| `erro` | `LEDR5` | `PIN_N1` | Indica tentativa de transbordo ou subfluxo |
| `hex0[6..0]` | `HEX0` (Unidades) | `PIN_AA22, Y21, Y22, W21, W22, V21, U21` | Dígito das unidades (ânodo comum) |
| `hex1[6..0]` | `HEX1` (Dezenas) | `PIN_U22, AA17, AB18, AA18, AA19, AB20, AA20` | Dígito das dezenas (ânodo comum) |

---

## Simulação, Testbenches e Projeto Quartus

### Arquivos de Verificação
- **Testbenches VHDL:**
  - [`tb_controlador_esteira.vhd`](./tb_controlador_esteira.vhd): Verificação integrada do divisor, contagem, limites, pausa, pico e indicadores.
  - [`tb_decodificador_bcd.vhd`](./tb_decodificador_bcd.vhd): Teste dos 10 dígitos válidos (`0`–`9`) e dos 6 códigos BCD inválidos (`10`–`15`).
  - [`tb_teste9_visualizacao.vhd`](./tb_teste9_visualizacao.vhd): Exercita os quatro modos de visualização em execução, pausa e reset.
- **Waveforms (Quartus Vector Waveform):**
  - [`Waveform.vwf`](./Waveform.vwf), [`Waveform1.vwf`](./Waveform1.vwf), [`Waveform_Decodificador.vwf`](./Waveform_Decodificador.vwf), [`Teste_1.vwf`](./Teste_1.vwf).

### Como Executar no Quartus Prime
1. Abra o projeto [`dlp_projeto.qpf`](./dlp_projeto.qpf) no Intel Quartus Prime.
2. Caso precise reaplicar a pinagem, execute o script Tcl via menu **Tools → Tcl Scripts... → `mapeamento_pinos.tcl` → Run**.
3. Para gravar na placa DE0-CV, certifique-se de que `H_SIMULATION => 0` em `dlp_projeto.vhd`, compile o projeto e programe o `.sof` gerado via **Programmer**.

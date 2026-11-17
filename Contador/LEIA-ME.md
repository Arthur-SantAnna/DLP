# Pratica 01 — Contador modulo 6 (0 a 5) com FSM em VHDL

## Objetivo
Desenvolver um contador sequencial com seis estados (S0 a S5), implementado como maquina de estados finitos Moore. Ao atingir 5, a proxima transicao retorna a 0.

## Arquivos
- `contador_mod6.vhd`: codigo para sintese e gravacao na FPGA.
- `tb_contador_mod6.vhd`: bancada de testes para simulacao funcional em ModelSim/Questa (nao sintetizar).

## Entradas e saidas
| Porta | Direcao | Funcao |
| --- | --- | --- |
| `clk` | Entrada | Clock fisico da FPGA. Valor padrao: 50 MHz (ajustar conforme placa). |
| `reset_n` | Entrada | Reset assincrono ativo em 0 (pressionar reset com nivel baixo). |
| `enable` | Entrada | 1 = avanca a cada segundo; 0 = pausa. Recomenda-se uma chave, nao botao sem debounce. |
| `leds(2 downto 0)` | Saida | Valor binario de 0 a 5. |
| `seg7_n(6 downto 0)` | Saida | Segmentos em ordem a,b,c,d,e,f,g, ativos em 0. |

## Estados
S0/000 -> S1/001 -> S2/010 -> S3/011 -> S4/100 -> S5/101 -> S0/000.
Cada transicao ocorre quando `enable=1` e o divisor contabiliza `CLK_FREQ_HZ` bordas do clock. Quando `enable=0`, o estado e mantido e o divisor e zerado. O reset força S0.

## Quartus II / Quartus Prime — sintese e FPGA
1. File > New Project Wizard. Escolher pasta e nome do projeto `contador_mod6`.
2. Adicionar **apenas** `contador_mod6.vhd` como arquivo de sintese.
3. Definir `contador_mod6` como **Top-Level Entity** (Project Navigator > Set as Top-Level Entity).
4. Selecionar dispositivo exatamente correspondente a FPGA instalada.
5. Conferir a frequencia do oscilador da placa. O generic `CLK_FREQ_HZ` vale 50_000_000 por padrao; se a placa for 25 MHz, mudar para 25_000_000. Nunca usar 4 na FPGA para essa demonstracao de 1 segundo.
6. Em Assignments > Pin Planner, mapear `clk`, `reset_n`, `enable`, `leds[0..2]` e, se forem usados, `seg7_n[0..6]` para os pinos da placa (consultar manual). Configurar o I/O standard conforme a placa.
7. Compile. Conectar por JTAG e gravar o arquivo `.sof` em Tools > Programmer.
8. Colocar `enable=1`: os LEDs devem mostrar 000, 001, 010, 011, 100, 101, e voltar a 000, com 1 segundo por valor. Colocar `enable=0`: pausa. Acionar o reset: 000.

**Atencao:** os segmentos sao **ativos em nivel baixo** e estao em ordem `a,b,c,d,e,f,g` de MSB para LSB. O layout fisico do display pode ter ordem diferente; adaptar o mapeamento conforme a placa. Se a placa nao tiver display, usar so os LEDs e deixar `seg7_n` sem pinos atribuidos, se permitido pelo fluxo de projeto.

**Atencao ao reset:** chave/tecla deve realmente produzir `0` quando acionada. Entradas mecanicas podem oscilar; para botao no lugar de chave `enable`, adicionar debounce e sincronizacao.

## Simulacao funcional
1. No ModelSim/Questa, criar um projeto e adicionar `contador_mod6.vhd` e `tb_contador_mod6.vhd`.
2. Compilar primeiro a implementacao, depois o testbench.
3. Simular `work.tb_contador_mod6` e executar `run -all`.
4. Observar `clk`, `reset_n`, `enable`, `leds`, `seg7_n` (opcional) e o estado interno `/tb_contador_mod6/dut/estado_atual`.
5. O testbench usa `CLK_FREQ_HZ => 4`, entao as transicoes ocorrem a cada quatro bordas de subida (80 ns com clock de 20 ns).
6. Confirmar que nao ha mensagens `severity error`. O teste verifica tambem o display de 7 segmentos e pausa no estado 2. A mensagem final `SIMULACAO CONCLUIDA` indica que os estimulos terminaram.

## Casos esperados
| Condicao | Esperado |
| --- | --- |
| Reset acionado (`reset_n=0`) | S0 e LEDs 000 imediatamente |
| `enable=1` e decorre 1 intervalo completo | Proximo estado |
| S5 + intervalo completo | S0 |
| `enable=0` | Permanece no estado atual |
| Retornar `enable=1` | Aguarda novo intervalo completo antes de avancar |

## Observacoes
Nao foi fornecido modelo de FPGA, frequencia do oscilador nem mapeamento dos pinos; por isso, esses detalhes devem ser ajustados antes de gravar o projeto. O codigo implementa uma FSM Moore de seis estados, com divisor de tempo sincrono e sem clocks derivados.

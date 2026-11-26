-- =====================================================================
-- PRÁTICA 03 - Gerador de sinal: y = '0' por 2 ciclos (2T0)
--                                 y = '1' por 6 ciclos (6T0)
--   Período = 8 ciclos de clock, ciclo de trabalho = 6/8 = 75 %.
--   Máquina de Moore com 8 estados (T0..T7):
--     T0, T1         -> y = '0'
--     T2 .. T7       -> y = '1'
--   Entradas: clk (pedida no enunciado) e resetn (ativo em '0', volta
--   para T0), no mesmo padrão da prática 01.
-- =====================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY gerador_sinal IS
  PORT (
    clk    : IN  STD_LOGIC;
    resetn : IN  STD_LOGIC;
    y      : OUT STD_LOGIC
  );
END gerador_sinal;

ARCHITECTURE fsm OF gerador_sinal IS
  TYPE estado_tipo IS (T0, T1, T2, T3, T4, T5, T6, T7);
  SIGNAL estado : estado_tipo;
BEGIN

  -- Registrador de estado + lógica de próximo estado
  PROCESS (clk, resetn)
  BEGIN
    IF resetn = '0' THEN
      estado <= T0;
    ELSIF (clk'EVENT AND clk = '1') THEN
      CASE estado IS
        WHEN T0 => estado <= T1;
        WHEN T1 => estado <= T2;
        WHEN T2 => estado <= T3;
        WHEN T3 => estado <= T4;
        WHEN T4 => estado <= T5;
        WHEN T5 => estado <= T6;
        WHEN T6 => estado <= T7;
        WHEN T7 => estado <= T0;
      END CASE;
    END IF;
  END PROCESS;

  -- Saída Moore: depende só do estado
  y <= '0' WHEN (estado = T0 OR estado = T1) ELSE '1';

END fsm;
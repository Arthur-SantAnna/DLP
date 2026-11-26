-- =====================================================================
-- PRÁTICA 02 - Motor de passo unipolar, modo WAVE (1 fase por vez)
--   Pinos (conforme tabela do slide 21):
--     reset   : retorna ao estado inicial (ativo em '0', assíncrono)
--     clk     : velocidade do motor (1 passo por borda de subida)
--     sentido : '0' = horário  (A -> B -> C -> D -> A ...)
--               '1' = anti-horário (A -> D -> C -> B -> A ...)
--     A,B,C,D : saídas das fases 1..4
--   Máquina de Moore com 4 estados, um por fase energizada.
-- =====================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY motor_passo_wave IS
  PORT (
    clk     : IN  STD_LOGIC;
    reset   : IN  STD_LOGIC;   -- ativo em '0'
    sentido : IN  STD_LOGIC;
    A, B, C, D : OUT STD_LOGIC
  );
END motor_passo_wave;

ARCHITECTURE fsm OF motor_passo_wave IS
  TYPE estado_tipo IS (FASE_A, FASE_B, FASE_C, FASE_D);
  SIGNAL estado : estado_tipo;
BEGIN

  PROCESS (clk, reset)
  BEGIN
    IF reset = '0' THEN
      estado <= FASE_A;
    ELSIF (clk'EVENT AND clk = '1') THEN
      CASE estado IS
        WHEN FASE_A =>
          IF sentido = '0' THEN estado <= FASE_B; ELSE estado <= FASE_D; END IF;
        WHEN FASE_B =>
          IF sentido = '0' THEN estado <= FASE_C; ELSE estado <= FASE_A; END IF;
        WHEN FASE_C =>
          IF sentido = '0' THEN estado <= FASE_D; ELSE estado <= FASE_B; END IF;
        WHEN FASE_D =>
          IF sentido = '0' THEN estado <= FASE_A; ELSE estado <= FASE_C; END IF;
      END CASE;
    END IF;
  END PROCESS;

  -- Saídas (Moore): apenas uma fase ativa por estado
  A <= '1' WHEN estado = FASE_A ELSE '0';
  B <= '1' WHEN estado = FASE_B ELSE '0';
  C <= '1' WHEN estado = FASE_C ELSE '0';
  D <= '1' WHEN estado = FASE_D ELSE '0';

END fsm;
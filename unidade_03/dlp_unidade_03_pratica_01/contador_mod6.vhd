-- =====================================================================
-- PRÁTICA 01 - Contador módulo 6 (0 a 5) como Máquina de Moore
--   Estados: S0 -> S1 -> S2 -> S3 -> S4 -> S5 -> S0 ...
--   Saída q depende apenas do estado atual (Moore).
--   resetn assíncrono, ativo em '0' (volta para S0).
-- Esta é a entidade usada na simulação funcional (VWF / testbench).
-- =====================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY contador_mod6 IS
  PORT (
    clk    : IN  STD_LOGIC;
    resetn : IN  STD_LOGIC;
    q      : OUT STD_LOGIC_VECTOR(2 DOWNTO 0)
  );
END contador_mod6;

ARCHITECTURE fsm OF contador_mod6 IS
  TYPE estado_tipo IS (S0, S1, S2, S3, S4, S5);
  SIGNAL estado : estado_tipo;
BEGIN

  -- Registrador de estado + lógica de próximo estado
  PROCESS (clk, resetn)
  BEGIN
    IF resetn = '0' THEN
      estado <= S0;
    ELSIF (clk'EVENT AND clk = '1') THEN
      CASE estado IS
        WHEN S0 => estado <= S1;
        WHEN S1 => estado <= S2;
        WHEN S2 => estado <= S3;
        WHEN S3 => estado <= S4;
        WHEN S4 => estado <= S5;
        WHEN S5 => estado <= S0;
      END CASE;
    END IF;
  END PROCESS;

  -- Lógica de saída (Moore): depende só do estado
  WITH estado SELECT
    q <= "000" WHEN S0,
         "001" WHEN S1,
         "010" WHEN S2,
         "011" WHEN S3,
         "100" WHEN S4,
         "101" WHEN S5;

END fsm;


-- =====================================================================
-- divisor_frequencia.vhd
-- Gera, a partir do clock de 50 MHz da DE0-CV:
--   sinal_div    : onda quadrada de TARGET_FREQ_HZ (duty 50 %)
--   pulso_avanco : pulso de 1 ciclo de clk_50 na borda de SUBIDA de
--                  sinal_div (útil como clock enable)
--
--   Semiciclo H = CLOCK_IN_HZ / (2 * TARGET_FREQ_HZ)
--     Ex.: 2 Hz com 50 MHz -> H = 12.500.000 ciclos
--
-- H_SIMULATION:
--   0  -> calcula H automaticamente (USE ESTE VALOR NA PLACA)
--   >0 -> força H = H_SIMULATION (ex.: 4) para simular no VWF/ModelSim
--         sem esperar milhões de ciclos.
--
-- resetn ativo em '0', igual ao KEY0 da DE0-CV.
-- =====================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY divisor_frequencia IS
  GENERIC (
    CLOCK_IN_HZ    : INTEGER := 50_000_000;  -- clock da placa
    TARGET_FREQ_HZ : INTEGER := 2;           -- frequência desejada
    H_SIMULATION   : INTEGER := 0            -- 0 = hardware; >0 = simulação
  );
  PORT (
    clk_50       : IN  STD_LOGIC;
    resetn       : IN  STD_LOGIC;            -- ativo em '0'
    sinal_div    : OUT STD_LOGIC;
    pulso_avanco : OUT STD_LOGIC
  );
END divisor_frequencia;

ARCHITECTURE rtl OF divisor_frequencia IS

  -- Número de ciclos de clk_50 em cada semiciclo de sinal_div
  FUNCTION calcula_semiciclo RETURN INTEGER IS
  BEGIN
    IF H_SIMULATION > 0 THEN
      RETURN H_SIMULATION;
    ELSE
      RETURN CLOCK_IN_HZ / (2 * TARGET_FREQ_HZ);
    END IF;
  END FUNCTION;

  CONSTANT CICLOS_SEMICICLO : INTEGER := calcula_semiciclo;

  SIGNAL cnt           : INTEGER RANGE 0 TO CICLOS_SEMICICLO - 1 := 0;
  SIGNAL sinal_div_reg : STD_LOGIC := '0';

BEGIN

  ASSERT CICLOS_SEMICICLO >= 1
    REPORT "divisor_frequencia: TARGET_FREQ_HZ alto demais para CLOCK_IN_HZ"
    SEVERITY FAILURE;

  PROCESS (clk_50, resetn)
  BEGIN
    IF resetn = '0' THEN
      cnt           <= 0;
      sinal_div_reg <= '0';
      pulso_avanco  <= '0';

    ELSIF (clk_50'EVENT AND clk_50 = '1') THEN
      IF cnt = CICLOS_SEMICICLO - 1 THEN
        cnt           <= 0;
        sinal_div_reg <= NOT sinal_div_reg;
        -- pulso só quando sinal_div vai de '0' para '1'
        IF sinal_div_reg = '0' THEN
          pulso_avanco <= '1';
        ELSE
          pulso_avanco <= '0';
        END IF;

      ELSE
        cnt          <= cnt + 1;
        pulso_avanco <= '0';
      END IF;
    END IF;
  END PROCESS;

  sinal_div <= sinal_div_reg;

END rtl;
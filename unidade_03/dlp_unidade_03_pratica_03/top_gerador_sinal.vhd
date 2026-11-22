-- =====================================================================
-- PRÁTICA 03 - Top-level para a placa DE0-CV
--   CLOCK_50 -> divisor_frequencia (1 Hz) -> gerador_sinal
--   KEY(0)   -> reset (ativo em '0')
--   LEDR(0)  mostra y: 2 s apagado e 6 s aceso
--   HEX0     mostra o nível de y (0 ou 1)
--   LEDR(9)  pisca com o clock lento (T0 = 1 s)
-- Defina ESTA entidade como Top-Level no Quartus para gravar na FPGA.
-- =====================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY top_gerador_sinal IS
  GENERIC (
    -- 0 = placa (1 Hz real). Só o testbench muda (ex.: 4) para simular rápido.
    H_SIMULATION : INTEGER := 0
  );
  PORT (
    CLOCK_50 : IN  STD_LOGIC;
    KEY      : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
    LEDR     : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    HEX0     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
  );
END top_gerador_sinal;

ARCHITECTURE estrutural OF top_gerador_sinal IS
  SIGNAL clk_lento : STD_LOGIC;
  SIGNAL y         : STD_LOGIC;
  SIGNAL y4        : STD_LOGIC_VECTOR(3 DOWNTO 0);  -- y com 4 bits p/ o decodificador
BEGIN

  y4 <= "000" & y;   -- (VHDL-93 não aceita expressão direto no PORT MAP)

  U_DIV : ENTITY work.divisor_frequencia
    GENERIC MAP ( CLOCK_IN_HZ    => 50_000_000,
                  TARGET_FREQ_HZ => 1,
                  H_SIMULATION   => H_SIMULATION )
    PORT MAP ( clk_50       => CLOCK_50,
               resetn       => KEY(0),
               sinal_div    => clk_lento,
               pulso_avanco => OPEN );

  U_GER : ENTITY work.gerador_sinal
    PORT MAP ( clk => clk_lento, resetn => KEY(0), y => y );

  U_HEX0 : ENTITY work.decod_7seg
    PORT MAP ( valor => y4, seg => HEX0 );

  LEDR(0)          <= y;
  LEDR(8 DOWNTO 1) <= (OTHERS => '0');
  LEDR(9)          <= clk_lento;

END estrutural;
-- =====================================================================
-- PRÁTICA 01 - Top-level para a placa DE0-CV
--   CLOCK_50 -> divisor_frequencia (1 Hz) -> contador_mod6
--   KEY(0)   -> reset (ativo em '0')
--   LEDR(2..0) mostra q em binário, HEX0 mostra q em decimal
--   LEDR(9) pisca com o clock lento (para ver o ritmo)
-- Defina ESTA entidade como Top-Level no Quartus para gravar na FPGA.
-- =====================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY top_contador_mod6 IS
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
END top_contador_mod6;

ARCHITECTURE estrutural OF top_contador_mod6 IS
  SIGNAL clk_lento : STD_LOGIC;
  SIGNAL q         : STD_LOGIC_VECTOR(2 DOWNTO 0);
  SIGNAL q4        : STD_LOGIC_VECTOR(3 DOWNTO 0);  -- q com 4 bits p/ o decodificador
BEGIN

  q4 <= '0' & q;   -- (VHDL-93 não aceita expressão direto no PORT MAP)

  U_DIV : ENTITY work.divisor_frequencia
    GENERIC MAP ( CLOCK_IN_HZ => 50_000_000, TARGET_FREQ_HZ => 1,
                  H_SIMULATION => H_SIMULATION )
    PORT MAP ( clk_50 => CLOCK_50, resetn => KEY(0),
               sinal_div => clk_lento, pulso_avanco => OPEN );

  U_CONT : ENTITY work.contador_mod6
    PORT MAP ( clk => clk_lento, resetn => KEY(0), q => q );

  U_HEX0 : ENTITY work.decod_7seg
    PORT MAP ( valor => q4, seg => HEX0 );

  LEDR(2 DOWNTO 0) <= q;
  LEDR(8 DOWNTO 3) <= (OTHERS => '0');
  LEDR(9)          <= clk_lento;

END estrutural;
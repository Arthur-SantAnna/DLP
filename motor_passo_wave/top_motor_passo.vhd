-- =====================================================================
-- PRÁTICA 02 - Top-level para a placa DE0-CV (motor de passo, modo wave)
--   CLOCK_50 -> divisor_frequencia (2 Hz ou 200 Hz) -> motor_passo_wave
--   KEY(0)   -> reset (ativo em '0', volta para a fase A)
--   SW(0)    -> sentido ('0' horário, '1' anti-horário)
--   SW(1)    -> velocidade: '0' = 2 passos/s (dá para ver nos LEDs)
--                           '1' = 200 passos/s (motor girando)
--   LEDR(3..0) = D C B A (fases)   LEDR(8) = sentido   LEDR(9) = clock
--   HEX0       = número da fase ativa (A = 1, B = 2, C = 3, D = 4)
--   GPIO_0(0..3) = A B C D -> IN1..IN4 do driver ULN2003
--   (motor 28BYJ-48 5 V: alimentar o driver com 5 V e GND comum)
-- Defina ESTA entidade como Top-Level no Quartus para gravar na FPGA.
-- =====================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY top_motor_passo IS
  GENERIC (
    -- 0 = placa (frequências reais). Só o testbench muda (ex.: 4).
    H_SIMULATION : INTEGER := 0
  );
  PORT (
    CLOCK_50 : IN  STD_LOGIC;
    KEY      : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
    SW       : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
    LEDR     : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    HEX0     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    GPIO_0   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END top_motor_passo;

ARCHITECTURE estrutural OF top_motor_passo IS
  SIGNAL clk_2hz, clk_200hz, clk_motor : STD_LOGIC;
  SIGNAL fA, fB, fC, fD : STD_LOGIC;
  SIGNAL fases          : STD_LOGIC_VECTOR(3 DOWNTO 0);   -- D C B A
  SIGNAL num_fase       : STD_LOGIC_VECTOR(3 DOWNTO 0);   -- 1..4 p/ o display
BEGIN

  -- ---------- Divisores: 2 Hz (LEDs) e 200 Hz (motor) ----------
  U_DIV_LENTO : ENTITY work.divisor_frequencia
    GENERIC MAP ( CLOCK_IN_HZ    => 50_000_000,
                  TARGET_FREQ_HZ => 2,
                  H_SIMULATION   => H_SIMULATION )
    PORT MAP ( clk_50       => CLOCK_50,
               resetn       => KEY(0),
               sinal_div    => clk_2hz,
               pulso_avanco => OPEN );

  U_DIV_RAPIDO : ENTITY work.divisor_frequencia
    GENERIC MAP ( CLOCK_IN_HZ    => 50_000_000,
                  TARGET_FREQ_HZ => 200,
                  H_SIMULATION   => H_SIMULATION )
    PORT MAP ( clk_50       => CLOCK_50,
               resetn       => KEY(0),
               sinal_div    => clk_200hz,
               pulso_avanco => OPEN );

  clk_motor <= clk_200hz WHEN SW(1) = '1' ELSE clk_2hz;

  -- ---------- FSM do motor ----------
  U_MOTOR : ENTITY work.motor_passo_wave
    PORT MAP ( clk => clk_motor, reset => KEY(0), sentido => SW(0),
               A => fA, B => fB, C => fC, D => fD );

  fases <= fD & fC & fB & fA;

  -- ---------- Display: número da fase ativa (combinacional) ----------
  WITH fases SELECT
    num_fase <= "0001" WHEN "0001",   -- fase A = 1
                "0010" WHEN "0010",   -- fase B = 2
                "0011" WHEN "0100",   -- fase C = 3
                "0100" WHEN "1000",   -- fase D = 4
                "0000" WHEN OTHERS;

  U_HEX0 : ENTITY work.decod_7seg
    PORT MAP ( valor => num_fase, seg => HEX0 );

  -- ---------- LEDs e saída para o driver ----------
  LEDR(3 DOWNTO 0) <= fases;
  LEDR(7 DOWNTO 4) <= (OTHERS => '0');
  LEDR(8)          <= SW(0);          -- sentido
  LEDR(9)          <= clk_motor;      -- ritmo dos passos

  GPIO_0 <= fases;                    -- GPIO_0(0)=A ... GPIO_0(3)=D

END estrutural;
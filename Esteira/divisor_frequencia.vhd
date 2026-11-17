library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity divisor_frequencia is
    generic (
        CLOCK_IN_HZ    : integer := 50000000; -- Frequência do clock da placa (50 MHz)
        TARGET_FREQ_HZ : integer := 2;        -- Frequência desejada (2 Hz)
        
        -- H_SIMULATION: Mantenha em 0 para cálculo automático de hardware (ex: 2 Hz em 50 MHz = 12.500.000 ciclos).
        -- Em simulação (ModelSim / VWF), altere este parâmetro para um valor pequeno (ex: 4 ou 5) no Testbench/Top-Level.
        H_SIMULATION   : integer := 4
    );
    port (
        clk_50       : in  std_logic;
        rst          : in  std_logic;
        pausa        : in  std_logic;
        sinal_div    : out std_logic;
        pulso_avanco : out std_logic
    );
end entity;

architecture Behavioral of divisor_frequencia is

    -- Função que calcula o número de ciclos do semiciclo (H)
    function get_half_period_cycles return integer is
    begin
        if H_SIMULATION > 0 then
            return H_SIMULATION;
        else
            return CLOCK_IN_HZ / (2 * TARGET_FREQ_HZ);
        end if;
    end function;

    constant CYCLES_PER_HALF_PERIOD : integer := get_half_period_cycles;

    signal cnt           : integer range 0 to CYCLES_PER_HALF_PERIOD - 1 := 0;
    signal sinal_div_reg : std_logic := '0';

begin

    process(clk_50, rst)
    begin
        if rst = '1' then
            cnt           <= 0;
            sinal_div_reg <= '0';
            pulso_avanco  <= '0';
        elsif rising_edge(clk_50) then
            if pausa = '1' then
                cnt           <= 0;
                sinal_div_reg <= '0';
                pulso_avanco  <= '0';
            else
                if cnt = CYCLES_PER_HALF_PERIOD - 1 then
                    cnt           <= 0;
                    sinal_div_reg <= not sinal_div_reg;
                    
                    -- Pulso de avanço ativado apenas na transição de subida de sinal_div
                    if sinal_div_reg = '0' then
                        pulso_avanco <= '1';
                    else
                        pulso_avanco <= '0';
                    end if;
                else
                    cnt          <= cnt + 1;
                    pulso_avanco <= '0';
                end if;
            end if;
        end if;
    end process;

    sinal_div <= sinal_div_reg;

end architecture;
--------------------------------------------------------------------------------
-- Arquivo: divisor_frequencia.vhd
-- Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
-- Descricao: Divisor de frequencia sincrono (baseado no modulo utilizado na
--            pratica da Esteira), reduzindo o clock nativo de 50 MHz da placa
--            DE0-CV para 2 Hz (periodo de 0.5s) atraves de 'sinal_div' e do
--            pulso de clock-enable 'pulso_avanco' (1 ciclo de clk_50).
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity divisor_frequencia is
    generic (
        CLOCK_IN_HZ    : integer := 50000000; -- Frequencia do clock da placa DE0-CV (50 MHz)
        TARGET_FREQ_HZ : integer := 2;        -- Frequencia desejada para a FSM (2 Hz -> passo de 0.5s)
        
        -- H_SIMULATION:
        --   * 0 = Calculo automatico para Hardware/FPGA (2 Hz em 50 MHz = 12.500.000 ciclos por semiciclo)
        --   * > 0 (ex: 4) = Modo Simulacao rapida no ModelSim / VWF (4 ciclos por semiciclo)
        H_SIMULATION   : integer := 0
    );
    port (
        clk_50       : in  std_logic;
        rst          : in  std_logic; -- Reset ativo em nivel alto ('1')
        pausa        : in  std_logic;
        sinal_div    : out std_logic;
        pulso_avanco : out std_logic
    );
end entity divisor_frequencia;

architecture Behavioral of divisor_frequencia is

    -- Funcao que calcula o numero de ciclos do semiciclo (H)
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
                    
                    -- Pulso de avanco ativado apenas na transicao de subida de sinal_div
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

end architecture Behavioral;

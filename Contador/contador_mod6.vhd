-- Pratica 01 - Contador modulo 6 (0 a 5)
-- Implementacao em VHDL por maquina de estados finitos (FSM)
-- Saidas: 3 LEDs em binario e um display de 7 segmentos ativo em nivel baixo.
-- Compatibilidade: VHDL-93 (Quartus II / Quartus Prime)
-- CLK_FREQ_HZ deve ser igual a frequencia do clock fisico da placa.

library ieee;
use ieee.std_logic_1164.all;

entity contador_mod6 is
    generic (
        CLK_FREQ_HZ : positive := 50_000_000
    );
    port (
        clk      : in  std_logic;
        reset_n  : in  std_logic;                     -- reset ativo em 0
        enable   : in  std_logic;                     -- 1 = contar; 0 = pausar
        leds     : out std_logic_vector(2 downto 0); -- numero binario de 0 a 5
        seg7_n   : out std_logic_vector(6 downto 0)  -- a,b,c,d,e,f,g (ativo em 0)
    );
end entity contador_mod6;

architecture rtl of contador_mod6 is

    -- Cada valor da contagem corresponde a um ESTADO, nao apenas a um registrador.
    type estado_t is (S0, S1, S2, S3, S4, S5);
    signal estado_atual   : estado_t := S0;
    signal proximo_estado : estado_t := S0;

    -- Geracao de enable de 1 segundo, SEM criar um clock derivado.
    signal divisor : natural range 0 to CLK_FREQ_HZ - 1 := 0;

begin

    -- 1. Logica combinacional de proximo estado
    process (estado_atual)
    begin
        case estado_atual is
            when S0 => proximo_estado <= S1;
            when S1 => proximo_estado <= S2;
            when S2 => proximo_estado <= S3;
            when S3 => proximo_estado <= S4;
            when S4 => proximo_estado <= S5;
            when S5 => proximo_estado <= S0;
        end case;
    end process;

    -- 2. Registrador de estado + temporizacao sincrona
    process (clk, reset_n)
    begin
        if reset_n = '0' then
            estado_atual <= S0;
            divisor      <= 0;
        elsif rising_edge(clk) then
            if enable = '1' then
                if divisor = CLK_FREQ_HZ - 1 then
                    divisor      <= 0;
                    estado_atual <= proximo_estado;
                else
                    divisor <= divisor + 1;
                end if;
            else
                -- Pausa no estado atual; ao retomar conta 1 segundo completo.
                divisor <= 0;
            end if;
        end if;
    end process;

    -- 3. Logica de saida Moore: depende apenas do estado atual.
    -- seg7_n: bits na ordem [a b c d e f g], ativo em nivel baixo.
    process (estado_atual)
    begin
        case estado_atual is
            when S0 =>
                leds   <= "000";
                seg7_n <= "0000001"; -- 0
            when S1 =>
                leds   <= "001";
                seg7_n <= "1001111"; -- 1
            when S2 =>
                leds   <= "010";
                seg7_n <= "0010010"; -- 2
            when S3 =>
                leds   <= "011";
                seg7_n <= "0000110"; -- 3
            when S4 =>
                leds   <= "100";
                seg7_n <= "1001100"; -- 4
            when S5 =>
                leds   <= "101";
                seg7_n <= "0100100"; -- 5
        end case;
    end process;

end architecture rtl;

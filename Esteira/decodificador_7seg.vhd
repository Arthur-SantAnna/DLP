library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decodificador_7seg is
    port (
        bcd : in  integer range 0 to 15;
        seg : out std_logic_vector(6 downto 0) -- g f e d c b a
    );
end entity;

architecture Behavioral of decodificador_7seg is
begin
    process(bcd)
    begin
        case bcd is
            when 0 => seg <= "1000000"; -- '0'
            when 1 => seg <= "1111001"; -- '1'
            when 2 => seg <= "0100100"; -- '2'
            when 3 => seg <= "0110000"; -- '3'
            when 4 => seg <= "0011001"; -- '4'
            when 5 => seg <= "0010010"; -- '5'
            when 6 => seg <= "0000010"; -- '6'
            when 7 => seg <= "1111000"; -- '7'
            when 8 => seg <= "0000000"; -- '8'
            when 9 => seg <= "0010000"; -- '9'
            when others => seg <= "1111111"; -- Apagado para BCDs inválidos (10-15)
        end case;
    end process;
end architecture;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seletor_exibicao is
    generic (
        C_CAPACIDADE : integer := 50
    );
    port (
        modo          : in  std_logic_vector(1 downto 0);
        N             : in  integer range 0 to 79;
        P             : in  integer range 0 to 79;
        valor_exibido : out integer range 0 to 79
    );
end entity;

architecture Behavioral of seletor_exibicao is
begin

    ------------------------------------------------------------------
    -- Versão 1: Atribuição Condicional com 'when ... else' (Utilizada)
    ------------------------------------------------------------------
    valor_exibido <= N                     when modo = "00" else
                     (C_CAPACIDADE - N)   when modo = "01" else
                     P                     when modo = "10" else
                     C_CAPACIDADE;              -- modo = "11"

    ------------------------------------------------------------------
    -- Versão 2: Atribuição Selecionada com 'with ... select' (Equivalente)
    ------------------------------------------------------------------
    -- with modo select
    --     valor_exibido <= N                   when "00",
    --                      (C_CAPACIDADE - N) when "01",
    --                      P                   when "10",
    --                      C_CAPACIDADE        when others; -- "11"

end architecture;
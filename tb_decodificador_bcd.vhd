library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_decodificador_bcd is
end entity;

architecture Behavioral of tb_decodificador_bcd is

    -- Sinais com os mesmos tipos da sua entity
    signal bcd_in  : integer range 0 to 15 := 0;
    signal seg_out : std_logic_vector(6 downto 0);

begin

    ------------------------------------------------------------------
    -- Instância corrigida com os nomes reais das portas (bcd e seg)
    ------------------------------------------------------------------
    UUT_DECODER: entity work.decodificador_7seg
        port map (
            bcd => bcd_in,
            seg => seg_out
        );

    ------------------------------------------------------------------
    -- Processo de Estímulos: Testa os valores de 0 a 15
    ------------------------------------------------------------------
    stim_proc : process
    begin
        report "=================================================";
        report "INICIANDO TESTE UNITARIO DO DECODIFICADOR 7 SEG";
        report "=================================================";

        for i in 0 to 15 loop
            bcd_in <= i;
            wait for 20 ns;

            if i <= 9 then
                report "Testando Digito BCD Valido: " & integer'image(i);
            else
                report "Testando Codigo Invalido (10-15): " & integer'image(i);
                
                -- Valida se a saída fica em "1111111" (totalmente apagado)
                assert (seg_out = "1111111")
                    report "ERRO: O display NAO apagou para o valor BCD " & integer'image(i)
                    severity error;
            end if;
        end loop;

        report "=================================================";
        report "TESTE CONCLUIDO COM SUCESSO!";
        report "=================================================";
        
        wait;
    end process;

end architecture;
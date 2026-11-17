-- Testbench para simulacao funcional da Pratica 01
-- A frequencia de teste usa CLK_FREQ_HZ=4 para acelerar as transicoes.
-- O teste verifica: sequencia 0-5-0, pause/resume e reset assincrono.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_contador_mod6 is
end entity tb_contador_mod6;

architecture sim of tb_contador_mod6 is
    constant PERIODO_CLK : time := 20 ns;
    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal enable  : std_logic := '0';
    signal leds    : std_logic_vector(2 downto 0);
    signal seg7_n  : std_logic_vector(6 downto 0);
    signal fim     : boolean := false;

    function seg_esperado(numero : natural) return std_logic_vector is
    begin
        case numero mod 6 is
            when 0 => return "0000001";
            when 1 => return "1001111";
            when 2 => return "0010010";
            when 3 => return "0000110";
            when 4 => return "1001100";
            when others => return "0100100";
        end case;
    end function;
begin

    dut : entity work.contador_mod6
        generic map (
            CLK_FREQ_HZ => 4  -- um passo a cada 4 bordas de subida
        )
        port map (
            clk     => clk,
            reset_n => reset_n,
            enable  => enable,
            leds    => leds,
            seg7_n  => seg7_n
        );

    gerador_clock : process
    begin
        while not fim loop
            clk <= '0';
            wait for PERIODO_CLK / 2;
            clk <= '1';
            wait for PERIODO_CLK / 2;
        end loop;
        wait;
    end process;

    estimulos : process
    begin
        -- Inicialmente, o reset mantem o contador no estado 0.
        wait for 2 * PERIODO_CLK;
        assert leds = "000"
            report "ERRO: reset inicial nao colocou contador em 0"
            severity error;

        reset_n <= '1';
        enable  <= '1';

        -- Duas voltas completas e mais dois passos: finaliza no estado 2.
        for passo in 1 to 14 loop
            for pulso in 1 to 4 loop
                wait until rising_edge(clk);
                wait for 1 ns;  -- espera o delta-cycle de atualizacao da saida
            end loop;

            assert leds = std_logic_vector(to_unsigned(passo mod 6, 3))
                report "ERRO: valor incorreto no passo " & integer'image(passo)
                severity error;
            assert seg7_n = seg_esperado(passo)
                report "ERRO: display de 7 segmentos incorreto no passo " & integer'image(passo)
                severity error;
        end loop;

        -- Pausar no estado 2 (nao zero) para verificar retencao do estado.
        enable <= '0';
        for pulso in 1 to 8 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert leds = "010"
                report "ERRO: contador mudou enquanto enable=0 (deveria ser 2)"
                severity error;
        end loop;

        -- Retomar: depois de quatro clocks deve estar em 3.
        enable <= '1';
        for pulso in 1 to 4 loop
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        assert leds = "011"
            report "ERRO: contador nao retomou no estado 3"
            severity error;

        -- Reset assincrono: a saida volta a 0 sem esperar pelo clock.
        reset_n <= '0';
        wait for 1 ns;
        assert leds = "000"
            report "ERRO: reset assincrono falhou"
            severity error;

        assert false report "SIMULACAO CONCLUIDA: todos os testes passaram, se nao houver erros acima."
            severity note;
        fim <= true;
        wait;
    end process;

end architecture sim;

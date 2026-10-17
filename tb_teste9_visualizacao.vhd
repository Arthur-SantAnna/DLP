library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_teste9_visualizacao is
end entity;

architecture Behavioral of tb_teste9_visualizacao is

    constant CLK_PERIOD : time := 20 ns;
    
    -- Parâmetros reduzidos para teste rápido
    constant C_CAPACIDADE           : integer := 12;
    constant L_LIMIAR               : integer := 8;
    constant CYCLES_PER_HALF_PERIOD : integer := 4;

    signal clk_50       : std_logic := '0';
    signal rst          : std_logic := '0';
    signal sentido      : std_logic := '0';
    signal pausa        : std_logic := '0';
    signal modo         : std_logic_vector(1 downto 0) := "00";

    signal cheio, vazio, alerta, erro, sinal_div, pulso_avanco : std_logic;
    signal hex1, hex0 : std_logic_vector(6 downto 0);

begin

    -- Instância do Top-Level (dlp_projeto)
    UUT : entity work.dlp_projeto
        generic map (
            C_CAPACIDADE           => C_CAPACIDADE,
            L_LIMIAR               => L_LIMIAR,
            CYCLES_PER_HALF_PERIOD => CYCLES_PER_HALF_PERIOD
        )
        port map (
            clk_50 => clk_50, rst => rst, sentido => sentido,
            pausa => pausa, modo => modo, cheio => cheio,
            vazio => vazio, alerta => alerta, erro => erro,
            sinal_div => sinal_div, pulso_avanco => pulso_avanco,
            hex1 => hex1, hex0 => hex0
        );

    -- Gerador de Clock
    clk_process : process
    begin
        clk_50 <= '0'; wait for CLK_PERIOD / 2;
        clk_50 <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- Processo de Estímulos para o Teste 9
    stim_proc : process
    begin
        report "=================================================";
        report "INICIANDO TESTE 9: EXERCITANDO OS 4 MODOS";
        report "=================================================";

        ------------------------------------------------------------------
        -- ETAPA 1: TESTAR MODOS DURANTE O RESET (rst = '1')
        ------------------------------------------------------------------
        report "--- ETAPA 1: Testando modos sob RESET ---";
        rst <= '1';
        wait for 40 ns;

        -- No Reset: N = 0, P = 0, C = 12
        modo <= "00"; wait for 40 ns; -- Deve exibir N = 0
        modo <= "01"; wait for 40 ns; -- Deve exibir C - N = 12
        modo <= "10"; wait for 40 ns; -- Deve exibir P = 0
        modo <= "11"; wait for 40 ns; -- Deve exibir C = 12

        ------------------------------------------------------------------
        -- ETAPA 2: TESTAR MODOS EM EXECUÇÃO NORMAL (rst = '0', pausa = '0')
        ------------------------------------------------------------------
        report "--- ETAPA 2: Incrementando sistema para gerar N e P distintos ---";
        rst <= '0';
        sentido <= '0'; -- Adicionar peças
        
        -- Aguarda alguns pulsos para incrementar N e armazenar pico P
        wait for 800 ns; 

        report "--- Testando modos em EXECUÇÃO ---";
        -- Supondo N = 5, P = 5, C = 12 (C - N = 7)
        modo <= "00"; wait for 60 ns; -- Exibe N
        modo <= "01"; wait for 60 ns; -- Exibe C - N
        modo <= "10"; wait for 60 ns; -- Exibe P
        modo <= "11"; wait for 60 ns; -- Exibe C

        ------------------------------------------------------------------
        -- ETAPA 3: TESTAR MODOS DURANTE A PAUSA (pausa = '1')
        ------------------------------------------------------------------
        report "--- ETAPA 3: Congelando sistema em PAUSA e chaveando modos ---";
        pausa <= '1';
        wait for 40 ns;

        modo <= "00"; wait for 60 ns; -- Exibe N (mantém valor pausado)
        modo <= "01"; wait for 60 ns; -- Exibe C - N
        modo <= "10"; wait for 60 ns; -- Exibe P
        modo <= "11"; wait for 60 ns; -- Exibe C
        
        pausa <= '0'; -- Retoma
        wait for 100 ns;

        report "=================================================";
        report "TESTE 9 CONCLUIDO COM SUCESSO!";
        report "=================================================";
        wait;
    end process;

end architecture;
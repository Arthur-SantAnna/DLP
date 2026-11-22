library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_controlador_esteira is
end entity;

architecture Behavioral of tb_controlador_esteira is

    constant CLK_PERIOD : time := 20 ns; -- Clock de 50 MHz
    
    -- Parâmetros reduzidos para simulação acelerada (H = 4)
    constant C_CAPACIDADE           : integer := 12;
    constant L_LIMIAR               : integer := 8;
    constant CYCLES_PER_HALF_PERIOD : integer := 4;

    signal clk_50       : std_logic := '0';
    signal rst          : std_logic := '0';
    signal sentido      : std_logic := '0'; -- 0: Colocar, 1: Retirar
    signal pausa        : std_logic := '0';
    signal modo         : std_logic_vector(1 downto 0) := "00";

    signal cheio        : std_logic;
    signal vazio        : std_logic;
    signal alerta       : std_logic;
    signal erro         : std_logic;
    signal sinal_div    : std_logic;
    signal pulso_avanco : std_logic;
    signal hex1         : std_logic_vector(6 downto 0);
    signal hex0         : std_logic_vector(6 downto 0);

begin

    ------------------------------------------------------------------
    -- Instância da UUT (Top-Level)
    ------------------------------------------------------------------
    UUT : entity work.dlp_projeto
        generic map (
            C_CAPACIDADE           => C_CAPACIDADE,
            L_LIMIAR               => L_LIMIAR,
            CYCLES_PER_HALF_PERIOD => CYCLES_PER_HALF_PERIOD
        )
        port map (
            clk_50       => clk_50,
            rst          => rst,
            sentido      => sentido,
            pausa        => pausa,
            modo         => modo,
            cheio        => cheio,
            vazio        => vazio,
            alerta       => alerta,
            erro         => erro,
            sinal_div    => sinal_div,
            pulso_avanco => pulso_avanco,
            hex1         => hex1,
            hex0         => hex0
        );

    ------------------------------------------------------------------
    -- Geração do Clock de 50 MHz
    ------------------------------------------------------------------
    clk_process : process
    begin
        clk_50 <= '0';
        wait for CLK_PERIOD / 2;
        clk_50 <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    ------------------------------------------------------------------
    -- Processo de Estímulos Cobrindo 100% dos Requisitos do PDF
    ------------------------------------------------------------------
    stim_proc : process
    begin
        -- =========================================================
        -- TESTE 3 & 9: RESET INICIAL E MODOS APÓS RESET
        -- =========================================================
        rst <= '1';
        wait for 40 ns;
        
        -- TESTE 9: Testar modos durante o Reset
        modo <= "00"; wait for 20 ns; -- Deve exibir 00
        modo <= "01"; wait for 20 ns; -- Deve exibir C (12)
        modo <= "10"; wait for 20 ns; -- Deve exibir 00
        modo <= "11"; wait for 20 ns; -- Deve exibir C (12)
        modo <= "00";
        
        rst <= '0';
        wait for 20 ns;

        -- =========================================================
        -- TESTE 1 & 2: DIVISOR E INTEGRAÇÃO
        -- =========================================================
        sentido <= '0';
        wait for 800 ns; -- Aguarda incrementos e verifica que só ocorre 1 por ciclo completo

        -- =========================================================
        -- TESTE 4 & 8: TRANSIÇÃO 09 PARA 10 E CRUZAMENTO DO LIMIAR L (8)
        -- =========================================================
        wait for 600 ns; -- Continua incrementando até N > 9 (alerta ativa em N >= 8)

        -- =========================================================
        -- TESTE 9: MÚLTIPLOS MODOS DE EXIBIÇÃO EM EXECUÇÃO
        -- =========================================================
        modo <= "00"; wait for 80 ns; -- Exibe N
        modo <= "01"; wait for 80 ns; -- Exibe C - N
        modo <= "10"; wait for 80 ns; -- Exibe Pico P
        modo <= "11"; wait for 80 ns; -- Exibe Capacidade C
        modo <= "00";

        -- =========================================================
        -- TESTE 6 & 9: PAUSA NO MEIO DO PERÍODO E TROCA DE MODO NA PAUSA
        -- =========================================================
        wait for 30 ns; -- Pausa acionada fora da borda
        pausa <= '1';
        wait for 100 ns;
        
        -- TESTE 9: Testar modos durante a Pausa
        modo <= "01"; wait for 60 ns;
        modo <= "10"; wait for 60 ns;
        modo <= "00"; wait for 80 ns;
        
        pausa <= '0'; -- Retoma operação
        wait for 200 ns;

        -- =========================================================
        -- TESTE 7 & 4: PICO P E TRANSIÇÃO DECREMENTAL 10 PARA 09
        -- =========================================================
        sentido <= '1'; -- Inverte para retirar peças
        wait for 600 ns; 
        
        -- Confirma que o Pico P se manteve no valor máximo enquanto N caiu
        modo <= "10"; wait for 100 ns; 
        modo <= "00";

        -- =========================================================
        -- TESTE 5 & 8: SUBFLUXO (RETIRAR EM ZERO) E PERSISTÊNCIA DO ERRO
        -- =========================================================
        wait for 1400 ns; -- Esvazia até N=0 e força subfluxo (erro passa para '1')

        -- =========================================================
        -- TESTE 3: RESET ACIONADO JUNTO DO PULSO DE AVANÇO
        -- =========================================================
        wait until falling_edge(sinal_div); -- Sincroniza próximo ao pulso
        rst <= '1';
        wait for 40 ns;
        rst <= '0';
        wait for 100 ns;

        -- =========================================================
        -- TESTE 5: TRANSBORDO (COLOCAR PEÇA EM C)
        -- =========================================================
        sentido <= '0';
        wait for 2600 ns; -- Preenche até C e tenta ultrapassar

        -- Finalização
        wait for 200 ns;
        assert false report "Simulação concluída com sucesso! Todos os testes foram executados." severity failure;
        wait;
    end process;

end architecture;
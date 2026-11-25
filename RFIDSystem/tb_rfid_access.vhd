--------------------------------------------------------------------------------
-- Arquivo: tb_rfid_access.vhd
-- Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
-- Descricao: Testbench completo para Simulacao Funcional no ModelSim / Quartus.
--            Utiliza o parametro H_SIMULATION => 2 no Divisor de Frequencia
--            (gerando 1 pulso_avanco a cada 4 ciclos de CLOCK_50 = 80 ns),
--            seguindo a mesma metodologia da pratica da Esteira.
--
-- Cenarios testados:
--   Caso 1: Leitura de cartao AUTORIZADO (0xA5) -> S_LENDO -> S_VERIFICANDO -> S_AUTORIZADO ("OPEn")
--   Caso 2: 3 tentativas INVALIDAS seguidas (0x11, 0x22, 0x33) -> S_NEGADO ("ErrO") -> S_BLOQUEADO ("LOCd")
--   Caso 3: Cadastro dinamico do cartao 0x33 via KEY[2] e nova leitura -> S_AUTORIZADO ("OPEn")
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rfid_access_pkg.all;

entity tb_rfid_access is
end entity tb_rfid_access;

architecture sim of tb_rfid_access is

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz

    signal CLOCK_50      : std_logic := '0';
    signal RESET_N       : std_logic := '0';
    signal KEY           : std_logic_vector(3 downto 0) := "1111";
    signal SW            : std_logic_vector(9 downto 0) := (others => '0');
    signal LEDR          : std_logic_vector(9 downto 0);
    signal HEX0          : std_logic_vector(6 downto 0);
    signal HEX1          : std_logic_vector(6 downto 0);
    signal HEX2          : std_logic_vector(6 downto 0);
    signal HEX3          : std_logic_vector(6 downto 0);
    signal HEX4          : std_logic_vector(6 downto 0);
    signal HEX5          : std_logic_vector(6 downto 0);
    signal RC522_CS_N    : std_logic;
    signal RC522_SCK     : std_logic;
    signal RC522_MOSI    : std_logic;
    signal RC522_MISO    : std_logic := '0';
    signal RC522_RST_N   : std_logic;

    signal sim_finished  : boolean := false;

begin

    -- Gerador de Clock de 50 MHz
    CLOCK_50 <= not CLOCK_50 after CLK_PERIOD / 2 when not sim_finished else '0';

    -- Instancia UUT do Top-Level com H_SIMULATION = 2 (1 pulso_avanco a cada 4 ciclos de clock)
    UUT : entity work.rfid_access_top
        generic map (
            CLOCK_IN_HZ    => 50000000,
            TARGET_FREQ_HZ => 2,
            H_SIMULATION   => 2
        )
        port map (
            CLOCK_50      => CLOCK_50,
            RESET_N       => RESET_N,
            KEY           => KEY,
            SW            => SW,
            LEDR          => LEDR,
            HEX0          => HEX0,
            HEX1          => HEX1,
            HEX2          => HEX2,
            HEX3          => HEX3,
            HEX4          => HEX4,
            HEX5          => HEX5,
            RC522_CS_N    => RC522_CS_N,
            RC522_SCK     => RC522_SCK,
            RC522_MOSI    => RC522_MOSI,
            RC522_MISO    => RC522_MISO,
            RC522_RST_N   => RC522_RST_N
        );

    -- Processo de Estimulos de Teste
    stim_proc : process
        -- Procedimento auxiliar para simular aproximacao de cartao (pressiona KEY[1])
        procedure present_card(constant id_byte : in std_logic_vector(7 downto 0)) is
        begin
            SW(7 downto 0) <= id_byte;
            wait for 2 * CLK_PERIOD;
            KEY(1) <= '0'; -- Pressiona botao de leitura (Ativo Baixo)
            wait for 2 * CLK_PERIOD;
            KEY(1) <= '1'; -- Solta botao
        end procedure;
    begin
        -- Inicializacao: Ativa Modo Simulacao nas chaves (SW[9] = '1')
        SW(9)   <= '1';
        SW(8)   <= '0';
        RESET_N <= '0';
        wait for 4 * CLK_PERIOD;
        RESET_N <= '1';
        wait for 4 * CLK_PERIOD;

        -- Verifica que iniciou em S_AGUARDANDO (state_code = "000", LEDR(9) = '0')
        assert LEDR(2 downto 0) = "000" and LEDR(9) = '0'
            report "Erro: Estado inicial deveria ser S_AGUARDANDO (000)" severity error;

        ------------------------------------------------------------------------
        -- CASO 1: Cartao Autorizado 1 (ID = 0xA5, presente na ROM AUTHORIZED_UIDS)
        ------------------------------------------------------------------------
        present_card(X"A5");

        -- Aguarda 2 pulsos_avanco (S_LENDO -> S_VERIFICANDO -> S_AUTORIZADO = ~10 ciclos)
        wait for 10 * CLK_PERIOD;
        assert LEDR(2 downto 0) = "011" and LEDR(9) = '1'
            report "Erro Caso 1: Cartao 0xA5 deveria liberar o acesso (S_AUTORIZADO)" severity error;

        -- Aguarda fim dos 6 pulsos_avanco de porta aberta (24 ciclos) e retorno a S_AGUARDANDO
        wait for 26 * CLK_PERIOD;
        assert LEDR(2 downto 0) = "000" and LEDR(9) = '0'
            report "Erro Caso 1: Deveria retornar para S_AGUARDANDO apos temporizador" severity error;

        ------------------------------------------------------------------------
        -- CASO 2: 3 Tentativas Invalidas Consecutivas -> Bloqueio (S_BLOQUEADO)
        ------------------------------------------------------------------------
        -- 1a Tentativa Invalida (ID = 0x11)
        present_card(X"11");
        wait for 10 * CLK_PERIOD;
        assert LEDR(2 downto 0) = "100" and LEDR(8) = '1' and LEDR(9) = '0'
            report "Erro Caso 2.1: Cartao 0x11 deveria ir para S_NEGADO" severity error;
        wait for 18 * CLK_PERIOD; -- Aguarda os 4 pulsos_avanco de S_NEGADO e volta a S_AGUARDANDO

        -- 2a Tentativa Invalida (ID = 0x22)
        present_card(X"22");
        wait for 10 * CLK_PERIOD;
        assert LEDR(2 downto 0) = "100" and LEDR(8) = '1'
            report "Erro Caso 2.2: Cartao 0x22 deveria ir para S_NEGADO" severity error;
        wait for 18 * CLK_PERIOD; -- Volta para S_AGUARDANDO

        -- 3a Tentativa Invalida (ID = 0x33) -> Deve entrar em S_BLOQUEADO ("101")!
        present_card(X"33");
        wait for 10 * CLK_PERIOD;
        assert LEDR(2 downto 0) = "101" and LEDR(6) = '1' and LEDR(9) = '0'
            report "Erro Caso 2.3: Na 3a falha consecutiva deveria entrar em S_BLOQUEADO (101)" severity error;

        -- Aguarda o desbloqueio automatico apos 10 pulsos_avanco (40 ciclos)
        wait for 42 * CLK_PERIOD;
        assert LEDR(2 downto 0) = "000"
            report "Erro Caso 2.3: Deveria retornar a S_AGUARDANDO apos fim do bloqueio" severity error;

        ------------------------------------------------------------------------
        -- CASO 3: Cadastro Dinamico de Cartao via Botao KEY[2] (Ate 4 Cartoes)
        ------------------------------------------------------------------------
        -- Pressiona KEY[2] para cadastrar o ultimo UID lido (0x33)
        KEY(2) <= '0';
        wait for 2 * CLK_PERIOD;
        KEY(2) <= '1';
        wait for 4 * CLK_PERIOD;
        assert LEDR(5) = '1'
            report "Erro Caso 3: LEDR(5) deveria indicar cartao dinamico cadastrado" severity error;

        -- Apresenta novamente o Cartao 0x33 -> Agora deve ser AUTORIZADO!
        present_card(X"33");
        wait for 10 * CLK_PERIOD;
        assert LEDR(2 downto 0) = "011" and LEDR(9) = '1'
            report "Erro Caso 3: Cartao recem-cadastrado 0x33 deveria ser AUTORIZADO!" severity error;

        wait for 30 * CLK_PERIOD;
        report "SIMULACAO CONCLUIDA COM SUCESSO! Todos os estados de Moore e Divisor de Frequencia validados." severity note;
        sim_finished <= true;
        wait;
    end process;

end architecture sim;

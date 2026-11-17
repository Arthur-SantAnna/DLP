--------------------------------------------------------------------------------
-- Arquivo: access_control_fsm.vhd
-- Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
-- Descricao: Maquina de Estados Finita de MOORE (FSM_Moore) que gerencia os
--            estados de autorizacao de usuarios via cartoes RFID, conforme os
--            conceitos e estrutura apresentados nos slides 5 a 11 da aula de
--            Dispositivos Logicos Programaveis (Prof. Joao Castelo).
--
-- Integracao com o Divisor de Frequencia (divisor_frequencia.vhd):
--   * A captura inicial do cartao em S_AGUARDANDO ocorre imediatamente no
--     clock de 50 MHz para nao perder o evento de leitura do RC522 ou botao.
--   * As transicoes temporizadas entre os estados (S_LENDO -> S_VERIFICANDO ->
--     S_AUTORIZADO / S_NEGADO / S_BLOQUEADO) sao cadenciadas pelo sinal
--     'pulso_avanco' (2 Hz na FPGA / 8 ciclos na simulacao), tornando cada
--     estado perfeitamente visivel nos displays de 7 segmentos e no ModelSim!
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rfid_access_pkg.all;

entity access_control_fsm is
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic; -- Reset ativo em nivel baixo ('0'), igual ao slide 9
        pulso_avanco    : in  std_logic; -- Pulso vindo do divisor_frequencia (2 Hz na placa)
        -- Entradas de Eventos de Cartao RFID
        card_detected   : in  std_logic; -- Pulso indicando presenca de cartao
        card_uid_in     : in  std_logic_vector(31 downto 0);
        -- Cadastro Dinamico de Cartao na Placa (Botao KEY[2] e KEY[3])
        enroll_btn      : in  std_logic; -- Cadastra o ultimo UID lido como autorizado
        clear_enroll    : in  std_logic; -- Remove o UID cadastrado dinamicamente
        -- Saidas Puras de Moore (Dependem exclusivamente do Estado Atual)
        trava_aberta    : out std_logic;                    -- Aciona atuador/rele e LED de Sucesso
        led_autorizado  : out std_logic;                    -- Indica estado S_AUTORIZADO
        led_negado      : out std_logic;                    -- Indica estado S_NEGADO
        led_bloqueado   : out std_logic;                    -- Indica estado S_BLOQUEADO
        display_msg     : out std_logic_vector(2 downto 0); -- Codigo da palavra para HEX3..HEX0
        state_code      : out std_logic_vector(2 downto 0); -- Codigo binario do estado atual (LEDR[2:0])
        -- Saidas Auxiliares de Diagnostico
        fail_count_out  : out std_logic_vector(1 downto 0); -- Numero de erros consecutivos (0 a 3)
        last_uid_out    : out std_logic_vector(31 downto 0);-- Ultimo UID capturado
        enrolled_active : out std_logic                     -- '1' se ha um cartao dinamico salvo
    );
end entity access_control_fsm;

architecture Behavior of access_control_fsm is

    -- Elemento de memoria S: Sinal enumerado que armazena o Estado Atual
    signal estado : state_type := S_AGUARDANDO;

    -- Duracao de cada estado em numero de pulsos do divisor de frequencia (2 Hz = 0.5s por pulso)
    constant PULSOS_LENDO       : integer := 1;  -- 1 pulso  (0.5s exibindo "rEAd")
    constant PULSOS_VERIFICANDO : integer := 1;  -- 1 pulso  (0.5s exibindo "ChEC")
    constant PULSOS_AUTORIZADO  : integer := 6;  -- 6 pulsos (3.0s exibindo "OPEn" e trava aberta)
    constant PULSOS_NEGADO      : integer := 4;  -- 4 pulsos (2.0s exibindo "ErrO")
    constant PULSOS_BLOQUEADO   : integer := 10; -- 10 pulsos (5.0s exibindo "LOCd")

    signal passo_cnt      : integer range 0 to 15 := 0;

    -- Registradores de Dados de Apoio
    signal uid_reg        : std_logic_vector(31 downto 0) := (others => '0');
    signal custom_uid_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal custom_valid   : std_logic := '0';
    signal id_valido      : std_logic := '0';
    signal fail_count     : unsigned(1 downto 0) := "00";

begin

    ----------------------------------------------------------------------------
    -- Comparador Combinacional de Autorizacao (Lista Interna ROM + Slot Dinamico)
    ----------------------------------------------------------------------------
    process(uid_reg, custom_uid_reg, custom_valid)
        variable match : std_logic;
    begin
        match := '0';
        -- Compara com a lista interna de cartoes autorizados (ROM)
        for i in AUTHORIZED_UIDS'range loop
            if uid_reg = AUTHORIZED_UIDS(i) then
                match := '1';
            end if;
        end loop;

        -- Compara tambem com o cartao cadastrado em tempo real via KEY[2]
        if custom_valid = '1' and uid_reg = custom_uid_reg then
            match := '1';
        end if;

        id_valido <= match;
    end process;

    ----------------------------------------------------------------------------
    -- Processo de Cadastro Dinamico de Cartao (Permite cadastrar a tag do kit)
    ----------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            custom_uid_reg <= (others => '0');
            custom_valid   <= '0';
        elsif rising_edge(clk) then
            if clear_enroll = '1' then
                custom_uid_reg <= (others => '0');
                custom_valid   <= '0';
            elsif enroll_btn = '1' and uid_reg /= X"00000000" then
                custom_uid_reg <= uid_reg;
                custom_valid   <= '1';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 1. PROCESSO DE CONTROLE DE ESTADO (Funcao de Proximo Estado T e Memoria S)
    -- Estrutura identica aos slides 6, 9 e 10 do material da aula
    ----------------------------------------------------------------------------
    process(reset_n, clk)
    begin
        if reset_n = '0' then
            -- S_AGUARDANDO e o estado inicial
            estado     <= S_AGUARDANDO;
            passo_cnt  <= 0;
            uid_reg    <= (others => '0');
            fail_count <= "00";

        elsif (clk'event and clk = '1') then
            case estado is

                -- Estado 0: Aguardando aproximacao de um cartao RFID
                when S_AGUARDANDO =>
                    passo_cnt <= 0;
                    if card_detected = '1' then
                        uid_reg <= card_uid_in;
                        estado  <= S_LENDO;
                    else
                        estado  <= S_AGUARDANDO;
                    end if;

                -- Estado 1: Leitura e captura do UID do cartao ("rEAd")
                when S_LENDO =>
                    if pulso_avanco = '1' then
                        if passo_cnt >= PULSOS_LENDO - 1 then
                            passo_cnt <= 0;
                            estado    <= S_VERIFICANDO;
                        else
                            passo_cnt <= passo_cnt + 1;
                            estado    <= S_LENDO;
                        end if;
                    end if;

                -- Estado 2: Verificacao do UID contra a lista interna ("ChEC")
                when S_VERIFICANDO =>
                    if pulso_avanco = '1' then
                        if passo_cnt >= PULSOS_VERIFICANDO - 1 then
                            passo_cnt <= 0;
                            if id_valido = '1' then
                                fail_count <= "00"; -- Zera contador de falhas ao acertar
                                estado     <= S_AUTORIZADO;
                            else
                                -- Se errar 3 vezes seguidas (ja tinha 2 erros + erro atual = 3)
                                if fail_count >= "10" then
                                    fail_count <= "11";
                                    estado     <= S_BLOQUEADO;
                                else
                                    fail_count <= fail_count + 1;
                                    estado     <= S_NEGADO;
                                end if;
                            end if;
                        else
                            passo_cnt <= passo_cnt + 1;
                            estado    <= S_VERIFICANDO;
                        end if;
                    end if;

                -- Estado 3: Acesso Autorizado ("OPEn" - Libera a trava por 6 pulsos = 3s)
                when S_AUTORIZADO =>
                    if pulso_avanco = '1' then
                        if passo_cnt >= PULSOS_AUTORIZADO - 1 then
                            passo_cnt <= 0;
                            estado    <= S_AGUARDANDO;
                        else
                            passo_cnt <= passo_cnt + 1;
                            estado    <= S_AUTORIZADO;
                        end if;
                    end if;

                -- Estado 4: Acesso Negado ("ErrO" - Mantem trava fechada por 4 pulsos = 2s)
                when S_NEGADO =>
                    if pulso_avanco = '1' then
                        if passo_cnt >= PULSOS_NEGADO - 1 then
                            passo_cnt <= 0;
                            estado    <= S_AGUARDANDO;
                        else
                            passo_cnt <= passo_cnt + 1;
                            estado    <= S_NEGADO;
                        end if;
                    end if;

                -- Estado 5: Sistema Bloqueado ("LOCd" - Bloqueado por 10 pulsos = 5s)
                when S_BLOQUEADO =>
                    if pulso_avanco = '1' then
                        if passo_cnt >= PULSOS_BLOQUEADO - 1 then
                            passo_cnt  <= 0;
                            fail_count <= "00";
                            estado     <= S_AGUARDANDO;
                        else
                            passo_cnt  <= passo_cnt + 1;
                            estado     <= S_BLOQUEADO;
                        end if;
                    end if;

            end case;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 2. LOGICA COMBINACIONAL DE SAIDA (Funcao G da Maquina de Moore)
    -- As saidas dependem EXCLUSIVAMENTE do Estado Atual (estado)
    ----------------------------------------------------------------------------
    process(estado)
    begin
        -- Valores padrao seguros
        trava_aberta   <= '0';
        led_autorizado <= '0';
        led_negado     <= '0';
        led_bloqueado  <= '0';
        display_msg    <= MSG_IDLE;
        state_code     <= "000";

        case estado is
            when S_AGUARDANDO =>
                trava_aberta   <= '0';
                led_autorizado <= '0';
                led_negado     <= '0';
                led_bloqueado  <= '0';
                display_msg    <= MSG_IDLE; -- "idLE"
                state_code     <= "000";

            when S_LENDO =>
                trava_aberta   <= '0';
                led_autorizado <= '0';
                led_negado     <= '0';
                led_bloqueado  <= '0';
                display_msg    <= MSG_READ; -- "rEAd"
                state_code     <= "001";

            when S_VERIFICANDO =>
                trava_aberta   <= '0';
                led_autorizado <= '0';
                led_negado     <= '0';
                led_bloqueado  <= '0';
                display_msg    <= MSG_CHEC; -- "ChEC"
                state_code     <= "010";

            when S_AUTORIZADO =>
                trava_aberta   <= '1';      -- Libera o acesso / Aciona rele
                led_autorizado <= '1';      -- Acende LED de Sucesso
                led_negado     <= '0';
                led_bloqueado  <= '0';
                display_msg    <= MSG_OPEN; -- "OPEn"
                state_code     <= "011";

            when S_NEGADO =>
                trava_aberta   <= '0';
                led_autorizado <= '0';
                led_negado     <= '1';      -- Acende LED de Erro
                led_bloqueado  <= '0';
                display_msg    <= MSG_ERRO; -- "ErrO"
                state_code     <= "100";

            when S_BLOQUEADO =>
                trava_aberta   <= '0';
                led_autorizado <= '0';
                led_negado     <= '1';
                led_bloqueado  <= '1';      -- Acende LED de Alarme/Bloqueio
                display_msg    <= MSG_LOCD; -- "LOCd"
                state_code     <= "101";
        end case;
    end process;

    -- Saidas de diagnostico
    fail_count_out  <= std_logic_vector(fail_count);
    last_uid_out    <= uid_reg;
    enrolled_active <= custom_valid;

end architecture Behavior;

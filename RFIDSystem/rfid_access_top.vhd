--------------------------------------------------------------------------------
-- Arquivo: rfid_access_top.vhd
-- Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
-- Placa Alvo: Terasic DE0-CV (Altera/Intel Cyclone V 5CEBA4F23C7)
-- Descricao: Entidade Top-Level do projeto no Quartus Prime.
--            Integra o Divisor de Frequencia (50 MHz -> 2 Hz), o leitor fisico
--            RFID-RC522 (via SPI no GPIO_0), as chaves e botoes on-board, a
--            Maquina de Estados de Moore de Controle de Acesso e os perifericos
--            de saida (LEDs, Displays HEX5..HEX0 e trava/rele).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rfid_access_pkg.all;

entity rfid_access_top is
    generic (
        CLOCK_IN_HZ    : integer := 50000000; -- Clock nativo da DE0-CV (50 MHz)
        TARGET_FREQ_HZ : integer := 2;        -- Frequencia de avanco da FSM (2 Hz -> 0.5s)
        -- H_SIMULATION:
        --   * 0 = Modo Hardware na FPGA (usa 50 MHz / 2 Hz = 12.500.000 ciclos)
        --   * > 0 (ex: 2 ou 4) = Modo Simulacao rapida no ModelSim / VWF
        H_SIMULATION   : integer := 0
    );
    port (
        -- Clock de 50 MHz e Botao de Reset Dedicado da DE0-CV
        CLOCK_50      : in  std_logic;                    -- PIN_M9
        RESET_N       : in  std_logic;                    -- PIN_P22 (Ativo Baixo)

        -- Pushbuttons da DE0-CV (Ativos em Nivel Baixo '0' com Schmitt Trigger)
        KEY           : in  std_logic_vector(3 downto 0); -- KEY[0..3]

        -- Slide Switches da DE0-CV
        SW            : in  std_logic_vector(9 downto 0); -- SW[0..9]

        -- LEDs Vermelhos de Usuario da DE0-CV (Ativos em Nivel Alto '1')
        LEDR          : out std_logic_vector(9 downto 0); -- LEDR[0..9]

        -- 6 Displays de 7 Segmentos da DE0-CV (Anodo Comum - Ativos em Nivel Baixo '0')
        HEX0          : out std_logic_vector(6 downto 0);
        HEX1          : out std_logic_vector(6 downto 0);
        HEX2          : out std_logic_vector(6 downto 0);
        HEX3          : out std_logic_vector(6 downto 0);
        HEX4          : out std_logic_vector(6 downto 0);
        HEX5          : out std_logic_vector(6 downto 0);

        -- Pinos do Header GPIO_0 para o Modulo RFID-RC522 (3.3V SPI) e Atuador
        RC522_CS_N    : out std_logic;                    -- GPIO_0[0] (PIN_N16) -> SDA/NSS
        RC522_SCK     : out std_logic;                    -- GPIO_0[1] (PIN_B16) -> SCK
        RC522_MOSI    : out std_logic;                    -- GPIO_0[2] (PIN_M16) -> MOSI
        RC522_MISO    : in  std_logic;                    -- GPIO_0[3] (PIN_C16) -> MISO
        RC522_RST_N   : out std_logic;                    -- GPIO_0[4] (PIN_D17) -> RST
        LOCK_ACTUATOR : out std_logic                     -- GPIO_0[5] (PIN_K20) -> Rele/Solenoide
    );
end entity rfid_access_top;

architecture rtl of rfid_access_top is

    -- Reset global (ativo baixo e ativo alto para o divisor_frequencia)
    signal sys_reset_n      : std_logic;
    signal sys_reset_high   : std_logic;

    -- Sinais do Divisor de Frequencia (igual a pratica da Esteira)
    signal sig_sinal_div    : std_logic;
    signal sig_pulso_avanco : std_logic;

    -- Sinais de sincronizacao e deteccao de borda dos botoes KEY[1], KEY[2], KEY[3]
    signal key1_sync        : std_logic_vector(2 downto 0) := "111";
    signal key2_sync        : std_logic_vector(2 downto 0) := "111";
    signal key3_sync        : std_logic_vector(2 downto 0) := "111";
    signal sim_read_pulse   : std_logic := '0';
    signal enroll_pulse     : std_logic := '0';
    signal clear_pulse      : std_logic := '0';

    -- Sinais entre SPI Master e Controlador RC522
    signal spi_start        : std_logic;
    signal spi_rw           : std_logic;
    signal spi_reg_addr     : std_logic_vector(5 downto 0);
    signal spi_tx_data      : std_logic_vector(7 downto 0);
    signal spi_rx_data      : std_logic_vector(7 downto 0);
    signal spi_busy         : std_logic;
    signal spi_done         : std_logic;

    -- Sinais vindos do Controlador RC522
    signal rc522_uid        : std_logic_vector(31 downto 0);
    signal rc522_valid      : std_logic;
    signal rc522_comm       : std_logic;
    signal rc522_version    : std_logic_vector(7 downto 0);

    -- Sinais multiplexados de Entrada para a FSM de Moore (RC522 Real vs Simulacao SW)
    signal mux_card_detect  : std_logic;
    signal mux_card_uid     : std_logic_vector(31 downto 0);

    -- Sinais de Saida da Maquina de Estados de Moore
    signal trava_aberta     : std_logic;
    signal led_autorizado   : std_logic;
    signal led_negado       : std_logic;
    signal led_bloqueado    : std_logic;
    signal display_msg      : std_logic_vector(2 downto 0);
    signal state_code       : std_logic_vector(2 downto 0);
    signal fail_count       : std_logic_vector(1 downto 0);
    signal last_uid         : std_logic_vector(31 downto 0);
    signal enrolled_active  : std_logic;

begin

    -- Reset global: Pressionar o botao RESET_N ou KEY[0] reinicia o sistema
    sys_reset_n    <= RESET_N and KEY(0);
    sys_reset_high <= not sys_reset_n;

    ----------------------------------------------------------------------------
    -- Instancia 0: Divisor de Frequencia (50 MHz -> 2 Hz na placa / H_SIMULATION na sim)
    ----------------------------------------------------------------------------
    U_DIVISOR : entity work.divisor_frequencia
        generic map (
            CLOCK_IN_HZ    => CLOCK_IN_HZ,
            TARGET_FREQ_HZ => TARGET_FREQ_HZ,
            H_SIMULATION   => H_SIMULATION
        )
        port map (
            clk_50       => CLOCK_50,
            rst          => sys_reset_high,
            pausa        => '0',
            sinal_div    => sig_sinal_div,
            pulso_avanco => sig_pulso_avanco
        );

    ----------------------------------------------------------------------------
    -- Detector de Borda de Descida para os Pushbuttons KEY[1..3] (Ativos Baixos)
    ----------------------------------------------------------------------------
    process(CLOCK_50, sys_reset_n)
    begin
        if sys_reset_n = '0' then
            key1_sync      <= "111";
            key2_sync      <= "111";
            key3_sync      <= "111";
            sim_read_pulse <= '0';
            enroll_pulse   <= '0';
            clear_pulse    <= '0';
        elsif rising_edge(CLOCK_50) then
            key1_sync <= key1_sync(1 downto 0) & KEY(1);
            key2_sync <= key2_sync(1 downto 0) & KEY(2);
            key3_sync <= key3_sync(1 downto 0) & KEY(3);

            -- Pulso de 1 ciclo quando o botao e pressionado ('1' -> '0')
            if key1_sync(2 downto 1) = "10" then
                sim_read_pulse <= '1';
            else
                sim_read_pulse <= '0';
            end if;

            if key2_sync(2 downto 1) = "10" then
                enroll_pulse <= '1';
            else
                enroll_pulse <= '0';
            end if;

            if key3_sync(2 downto 1) = "10" then
                clear_pulse <= '1';
            else
                clear_pulse <= '0';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Instancia 1: Transceptor SPI Master (Comunicacao fisica com MFRC522 a 1.56 MHz)
    ----------------------------------------------------------------------------
    u_spi_master : entity work.spi_master
        generic map (
            CLK_DIV => 16 -- 50 MHz / 32 = 1.56 MHz
        )
        port map (
            clk      => CLOCK_50,
            reset_n  => sys_reset_n,
            start    => spi_start,
            rw       => spi_rw,
            reg_addr => spi_reg_addr,
            tx_data  => spi_tx_data,
            rx_data  => spi_rx_data,
            busy     => spi_busy,
            done     => spi_done,
            spi_cs_n => RC522_CS_N,
            spi_sck  => RC522_SCK,
            spi_mosi => RC522_MOSI,
            spi_miso => RC522_MISO
        );

    ----------------------------------------------------------------------------
    -- Instancia 2: Controlador de Inicializacao e Polling ISO14443A do RC522
    ----------------------------------------------------------------------------
    u_rc522_ctrl : entity work.rc522_controller
        generic map (
            SIMULATION_MODE => (H_SIMULATION > 0)
        )
        port map (
            clk          => CLOCK_50,
            reset_n      => sys_reset_n,
            spi_start    => spi_start,
            spi_rw       => spi_rw,
            spi_reg_addr => spi_reg_addr,
            spi_tx_data  => spi_tx_data,
            spi_rx_data  => spi_rx_data,
            spi_busy     => spi_busy,
            spi_done     => spi_done,
            rc522_rst_n  => RC522_RST_N,
            card_uid     => rc522_uid,
            card_valid   => rc522_valid,
            comm_active  => rc522_comm,
            version_out  => rc522_version
        );

    ----------------------------------------------------------------------------
    -- Selecao de Fonte de Leitura (SW[9]):
    --   SW[9] = '0' -> Usa o Leitor RFID-RC522 Fisico (tambem aceita KEY[1] para teste)
    --   SW[9] = '1' -> Modo Simulacao / Teste Manual via Switches SW[7:0] + KEY[1]
    ----------------------------------------------------------------------------
    mux_card_detect <= sim_read_pulse when SW(9) = '1' else (rc522_valid or sim_read_pulse);
    mux_card_uid    <= (X"000000" & SW(7 downto 0)) when (SW(9) = '1' or rc522_valid = '0') else rc522_uid;

    ----------------------------------------------------------------------------
    -- Instancia 3: Maquina de Estados de Moore Principal (Controle de Acesso)
    ----------------------------------------------------------------------------
    u_access_fsm : entity work.access_control_fsm
        port map (
            clk             => CLOCK_50,
            reset_n         => sys_reset_n,
            pulso_avanco    => sig_pulso_avanco,
            card_detected   => mux_card_detect,
            card_uid_in     => mux_card_uid,
            enroll_btn      => enroll_pulse,
            clear_enroll    => clear_pulse,
            trava_aberta    => trava_aberta,
            led_autorizado  => led_autorizado,
            led_negado      => led_negado,
            led_bloqueado   => led_bloqueado,
            display_msg     => display_msg,
            state_code      => state_code,
            fail_count_out  => fail_count,
            last_uid_out    => last_uid,
            enrolled_active => enrolled_active
        );

    ----------------------------------------------------------------------------
    -- Instancia 4: Decodificador para os 6 Displays de 7 Segmentos (HEX5..HEX0)
    ----------------------------------------------------------------------------
    u_hex_decoder : entity work.hex_display_decoder
        port map (
            display_msg   => display_msg,
            uid_in        => last_uid,
            rc522_version => rc522_version,
            show_uid_mode => SW(8), -- SW[8]='1' mostra o UID Hex completo nos displays
            hex0          => HEX0,
            hex1          => HEX1,
            hex2          => HEX2,
            hex3          => HEX3,
            hex4          => HEX4,
            hex5          => HEX5
        );

    ----------------------------------------------------------------------------
    -- Mapeamento das Saidas Fisicas (LEDs e Atuador/Trava)
    ----------------------------------------------------------------------------
    LOCK_ACTUATOR    <= trava_aberta;       -- Pino GPIO_0[5] para Rele/Trava Eletrica

    LEDR(2 downto 0) <= state_code;         -- Codigo binario do Estado Atual da FSM de Moore
    LEDR(4 downto 3) <= fail_count;         -- Contador de tentativas invalidas (0 a 3)
    LEDR(5)          <= enrolled_active;    -- Aceso quando ha um cartao dinamico salvo (KEY[2])
    LEDR(6)          <= led_bloqueado;      -- Indica Estado S_BLOQUEADO (Alarme)
    LEDR(7)          <= sig_sinal_div;      -- Pisca a 2 Hz indicando o Divisor de Frequencia ativo!
    LEDR(8)          <= led_negado;         -- Indica Acesso Negado / Erro
    LEDR(9)          <= led_autorizado;     -- Indica Acesso Autorizado / Trava Aberta

end architecture rtl;

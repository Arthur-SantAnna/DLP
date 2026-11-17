--------------------------------------------------------------------------------
-- Arquivo: rc522_controller.vhd
-- Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
-- Descricao: Controlador em hardware para o modulo leitor RFID-RC522 via SPI.
--            Realiza a inicializacao automatica dos registradores do MFRC522,
--            ativa a antena de 13.56 MHz, executa os comandos ISO14443A
--            REQA (0x26) e ANTICOLLISION (0x93, 0x20) e extrai os 4 bytes (32 bits)
--            do UID do cartao RFID aproximado, validando o byte de BCC (XOR).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rfid_access_pkg.all;

entity rc522_controller is
    generic (
        SIMULATION_MODE : boolean := false
    );
    port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;
        -- Interface com o SPI Master
        spi_start    : out std_logic;
        spi_rw       : out std_logic;
        spi_reg_addr : out std_logic_vector(5 downto 0);
        spi_tx_data  : out std_logic_vector(7 downto 0);
        spi_rx_data  : in  std_logic_vector(7 downto 0);
        spi_busy     : in  std_logic;
        spi_done     : in  std_logic;
        -- Pino de Reset Fisico do modulo RC522
        rc522_rst_n  : out std_logic;
        -- Saidas do Cartao Lido
        card_uid     : out std_logic_vector(31 downto 0);
        card_valid   : out std_logic; -- Pulso de 1 ciclo quando um novo cartao e lido
        comm_active  : out std_logic  -- Indica atividade de comunicacao com o RC522
    );
end entity rc522_controller;

architecture rtl of rc522_controller is

    -- Sequencia de comandos da micro-FSM de controle do MFRC522
    type rc_state_type is (
        RC_HW_RESET,
        RC_WAIT_BOOT,
        RC_INIT_SEQ,
        RC_POLL_DELAY,
        RC_REQ_SEQ,
        RC_REQ_WAIT,
        RC_REQ_CHECK_IRQ,
        RC_REQ_CHECK_FIFO,
        RC_ANTI_SEQ,
        RC_ANTI_WAIT,
        RC_ANTI_CHECK_FIFO,
        RC_READ_UID,
        RC_VERIFY_BCC,
        RC_COOLDOWN
    );

    signal state       : rc_state_type := RC_HW_RESET;
    signal step_idx    : integer range 0 to 15 := 0;
    signal spi_issued  : std_logic := '0';

    -- Contadores de tempo (50 MHz: 50_000 ciclos = 1 ms)
    constant BOOT_CYCLES     : integer := 250000;   -- 5 ms
    constant TRANS_CYCLES    : integer := 200000;   -- 4 ms para resposta RF do cartao
    constant POLL_CYCLES     : integer := 2500000;  -- 50 ms entre leituras
    constant COOLDOWN_CYCLES : integer := 50000000; -- 1.0 s de intervalo apos ler um cartao

    signal timer_cnt   : integer range 0 to 50000000 := 0;

    -- Registradores de captura do UID (4 bytes + 1 byte BCC)
    type uid_buf_type is array (0 to 4) of std_logic_vector(7 downto 0);
    signal uid_buf     : uid_buf_type := (others => (others => '0'));
    signal last_uid    : std_logic_vector(31 downto 0) := (others => '0');

begin

    process(clk, reset_n)
        variable bcc_calc : std_logic_vector(7 downto 0);
    begin
        if reset_n = '0' then
            state        <= RC_HW_RESET;
            step_idx     <= 0;
            spi_issued   <= '0';
            timer_cnt    <= 0;
            spi_start    <= '0';
            spi_rw       <= '0';
            spi_reg_addr <= (others => '0');
            spi_tx_data  <= (others => '0');
            rc522_rst_n  <= '0';
            card_uid     <= (others => '0');
            card_valid   <= '0';
            comm_active  <= '0';
            uid_buf      <= (others => (others => '0'));
            last_uid     <= (others => '0');

        elsif rising_edge(clk) then
            spi_start  <= '0';
            card_valid <= '0';

            case state is
                ----------------------------------------------------------------
                -- 1. Pulso de Reset de Hardware no pino RST do RC522
                ----------------------------------------------------------------
                when RC_HW_RESET =>
                    rc522_rst_n <= '0';
                    comm_active <= '0';
                    if SIMULATION_MODE or timer_cnt >= 50000 then
                        rc522_rst_n <= '1';
                        timer_cnt   <= 0;
                        state       <= RC_WAIT_BOOT;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;

                when RC_WAIT_BOOT =>
                    if SIMULATION_MODE or timer_cnt >= BOOT_CYCLES then
                        timer_cnt  <= 0;
                        step_idx   <= 0;
                        spi_issued <= '0';
                        state      <= RC_INIT_SEQ;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;

                ----------------------------------------------------------------
                -- 2. Inicializacao dos Registradores Internos do MFRC522
                ----------------------------------------------------------------
                when RC_INIT_SEQ =>
                    comm_active <= '1';
                    if spi_issued = '0' and spi_busy = '0' then
                        spi_start  <= '1';
                        spi_rw     <= '0'; -- Escrita
                        spi_issued <= '1';
                        case step_idx is
                            when 0 => spi_reg_addr <= REG_COMMAND;     spi_tx_data <= PCD_RESETPHASE; -- Soft Reset
                            when 1 => spi_reg_addr <= REG_T_MODE;      spi_tx_data <= X"8D";          -- TAuto=1
                            when 2 => spi_reg_addr <= REG_T_PRESCALER; spi_tx_data <= X"3E";          -- TPrescaler
                            when 3 => spi_reg_addr <= REG_T_RELOAD_L;  spi_tx_data <= X"1E";          -- Timeout 30
                            when 4 => spi_reg_addr <= REG_T_RELOAD_H;  spi_tx_data <= X"00";
                            when 5 => spi_reg_addr <= REG_TX_ASK;      spi_tx_data <= X"40";          -- 100% ASK
                            when 6 => spi_reg_addr <= REG_MODE;        spi_tx_data <= X"3D";          -- CRC 0x6363
                            when 7 => spi_reg_addr <= REG_TX_CONTROL;  spi_tx_data <= X"83";          -- Liga Antena TX1/TX2
                            when others => spi_reg_addr <= REG_COMMAND; spi_tx_data <= PCD_IDLE;
                        end case;
                    elsif spi_done = '1' then
                        spi_issued <= '0';
                        if step_idx = 7 then
                            step_idx  <= 0;
                            timer_cnt <= 0;
                            state     <= RC_POLL_DELAY;
                        else
                            step_idx <= step_idx + 1;
                        end if;
                    end if;

                ----------------------------------------------------------------
                -- 3. Intervalo de Polling entre buscas de cartao (50 ms)
                ----------------------------------------------------------------
                when RC_POLL_DELAY =>
                    comm_active <= '0';
                    if SIMULATION_MODE or timer_cnt >= POLL_CYCLES then
                        timer_cnt  <= 0;
                        step_idx   <= 0;
                        spi_issued <= '0';
                        state      <= RC_REQ_SEQ;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;

                ----------------------------------------------------------------
                -- 4. Envia comando REQA (PICC_REQIDL = 0x26) para detectar cartao
                ----------------------------------------------------------------
                when RC_REQ_SEQ =>
                    comm_active <= '1';
                    if spi_issued = '0' and spi_busy = '0' then
                        spi_start  <= '1';
                        spi_rw     <= '0'; -- Escrita
                        spi_issued <= '1';
                        case step_idx is
                            when 0 => spi_reg_addr <= REG_COMMAND;     spi_tx_data <= PCD_IDLE;
                            when 1 => spi_reg_addr <= REG_COM_IRQ;     spi_tx_data <= X"7F";       -- Limpa IRQs
                            when 2 => spi_reg_addr <= REG_FIFO_LEVEL;  spi_tx_data <= X"80";       -- Flush FIFO
                            when 3 => spi_reg_addr <= REG_FIFO_DATA;   spi_tx_data <= PICC_REQIDL; -- 0x26
                            when 4 => spi_reg_addr <= REG_BIT_FRAMING; spi_tx_data <= X"07";       -- 7 bits
                            when 5 => spi_reg_addr <= REG_COMMAND;     spi_tx_data <= PCD_TRANSCEIVE;
                            when 6 => spi_reg_addr <= REG_BIT_FRAMING; spi_tx_data <= X"87";       -- StartSend=1
                            when others => spi_reg_addr <= REG_COMMAND; spi_tx_data <= PCD_IDLE;
                        end case;
                    elsif spi_done = '1' then
                        spi_issued <= '0';
                        if step_idx = 6 then
                            step_idx  <= 0;
                            timer_cnt <= 0;
                            state     <= RC_REQ_WAIT;
                        else
                            step_idx <= step_idx + 1;
                        end if;
                    end if;

                when RC_REQ_WAIT =>
                    if SIMULATION_MODE or timer_cnt >= TRANS_CYCLES then
                        timer_cnt  <= 0;
                        spi_issued <= '0';
                        state      <= RC_REQ_CHECK_IRQ;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;

                when RC_REQ_CHECK_IRQ =>
                    -- Le o registrador de erro para garantir que nao houve falha
                    if spi_issued = '0' and spi_busy = '0' then
                        spi_start    <= '1';
                        spi_rw       <= '1'; -- Leitura
                        spi_reg_addr <= REG_ERROR;
                        spi_tx_data  <= X"00";
                        spi_issued   <= '1';
                    elsif spi_done = '1' then
                        spi_issued <= '0';
                        -- Verifica se BufferOvfl, ParityErr ou ProtocolErr sao '0'
                        if (spi_rx_data and X"13") = X"00" then
                            state <= RC_REQ_CHECK_FIFO;
                        else
                            state <= RC_POLL_DELAY;
                        end if;
                    end if;

                when RC_REQ_CHECK_FIFO =>
                    -- Verifica se o cartao respondeu os 2 bytes de ATQA na FIFO
                    if spi_issued = '0' and spi_busy = '0' then
                        spi_start    <= '1';
                        spi_rw       <= '1'; -- Leitura
                        spi_reg_addr <= REG_FIFO_LEVEL;
                        spi_tx_data  <= X"00";
                        spi_issued   <= '1';
                    elsif spi_done = '1' then
                        spi_issued <= '0';
                        if unsigned(spi_rx_data) >= 2 then
                            step_idx <= 0;
                            state    <= RC_ANTI_SEQ; -- Cartao detectado! Inicia Anticollision
                        else
                            state    <= RC_POLL_DELAY;
                        end if;
                    end if;

                ----------------------------------------------------------------
                -- 5. Comando ANTICOLLISION (0x93, 0x20) para ler os 4 bytes de UID
                ----------------------------------------------------------------
                when RC_ANTI_SEQ =>
                    if spi_issued = '0' and spi_busy = '0' then
                        spi_start  <= '1';
                        spi_rw     <= '0'; -- Escrita
                        spi_issued <= '1';
                        case step_idx is
                            when 0 => spi_reg_addr <= REG_COMMAND;     spi_tx_data <= PCD_IDLE;
                            when 1 => spi_reg_addr <= REG_COM_IRQ;     spi_tx_data <= X"7F";
                            when 2 => spi_reg_addr <= REG_FIFO_LEVEL;  spi_tx_data <= X"80"; -- Flush FIFO
                            when 3 => spi_reg_addr <= REG_BIT_FRAMING; spi_tx_data <= X"00"; -- 8 bits
                            when 4 => spi_reg_addr <= REG_FIFO_DATA;   spi_tx_data <= PICC_ANTICOLL_CL1; -- 0x93
                            when 5 => spi_reg_addr <= REG_FIFO_DATA;   spi_tx_data <= X"20";             -- NVB = 0x20
                            when 6 => spi_reg_addr <= REG_COMMAND;     spi_tx_data <= PCD_TRANSCEIVE;
                            when 7 => spi_reg_addr <= REG_BIT_FRAMING; spi_tx_data <= X"80"; -- StartSend=1
                            when others => spi_reg_addr <= REG_COMMAND; spi_tx_data <= PCD_IDLE;
                        end case;
                    elsif spi_done = '1' then
                        spi_issued <= '0';
                        if step_idx = 7 then
                            step_idx  <= 0;
                            timer_cnt <= 0;
                            state     <= RC_ANTI_WAIT;
                        else
                            step_idx <= step_idx + 1;
                        end if;
                    end if;

                when RC_ANTI_WAIT =>
                    if SIMULATION_MODE or timer_cnt >= TRANS_CYCLES then
                        timer_cnt  <= 0;
                        spi_issued <= '0';
                        state      <= RC_ANTI_CHECK_FIFO;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;

                when RC_ANTI_CHECK_FIFO =>
                    if spi_issued = '0' and spi_busy = '0' then
                        spi_start    <= '1';
                        spi_rw       <= '1'; -- Leitura
                        spi_reg_addr <= REG_FIFO_LEVEL;
                        spi_tx_data  <= X"00";
                        spi_issued   <= '1';
                    elsif spi_done = '1' then
                        spi_issued <= '0';
                        if unsigned(spi_rx_data) >= 5 then
                            step_idx <= 0;
                            state    <= RC_READ_UID;
                        else
                            state    <= RC_POLL_DELAY;
                        end if;
                    end if;

                ----------------------------------------------------------------
                -- 6. Le os 5 bytes da FIFO (4 bytes de UID + 1 byte BCC)
                ----------------------------------------------------------------
                when RC_READ_UID =>
                    if spi_issued = '0' and spi_busy = '0' then
                        spi_start    <= '1';
                        spi_rw       <= '1'; -- Leitura
                        spi_reg_addr <= REG_FIFO_DATA;
                        spi_tx_data  <= X"00";
                        spi_issued   <= '1';
                    elsif spi_done = '1' then
                        spi_issued        <= '0';
                        uid_buf(step_idx) <= spi_rx_data;
                        if step_idx = 4 then
                            state <= RC_VERIFY_BCC;
                        else
                            step_idx <= step_idx + 1;
                        end if;
                    end if;

                when RC_VERIFY_BCC =>
                    bcc_calc := uid_buf(0) xor uid_buf(1) xor uid_buf(2) xor uid_buf(3);
                    if bcc_calc = uid_buf(4) and (uid_buf(0) & uid_buf(1) & uid_buf(2) & uid_buf(3)) /= X"00000000" then
                        last_uid   <= uid_buf(0) & uid_buf(1) & uid_buf(2) & uid_buf(3);
                        card_uid   <= uid_buf(0) & uid_buf(1) & uid_buf(2) & uid_buf(3);
                        card_valid <= '1';
                        timer_cnt  <= 0;
                        state      <= RC_COOLDOWN;
                    else
                        state      <= RC_POLL_DELAY;
                    end if;

                ----------------------------------------------------------------
                -- 7. Cooldown de 1s apos leitura bem-sucedida
                ----------------------------------------------------------------
                when RC_COOLDOWN =>
                    comm_active <= '0';
                    if SIMULATION_MODE or timer_cnt >= COOLDOWN_CYCLES then
                        timer_cnt <= 0;
                        state     <= RC_POLL_DELAY;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;

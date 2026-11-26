--------------------------------------------------------------------------------
-- Arquivo: spi_master.vhd
-- Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
-- Descricao: Transceptor SPI Master (Modo 0: CPOL=0, CPHA=0) para comunicacao
--            com o modulo leitor RFID-RC522 conectado ao GPIO_0 da FPGA.
--            Cada transacao envia 2 bytes (Byte de Endereco MFRC522 + Byte de
--            Dado de Escrita) e captura 1 byte de resposta em rx_data.
--
-- Formato do Byte de Endereco do MFRC522 no SPI:
--   Bit 7   : '1' para Leitura (Read), '0' para Escrita (Write)
--   Bits 6:1: Endereco do registrador (6 bits)
--   Bit 0   : Sempre '0'
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    generic (
        -- Divisor de clock SPI: 50 MHz / (2 * 16) = 1.5625 MHz (MFRC522 suporta ate 10 MHz)
        CLK_DIV : integer := 16
    );
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        -- Interface com o controlador RC522
        start     : in  std_logic;
        rw        : in  std_logic;                    -- '1' = Read, '0' = Write
        reg_addr  : in  std_logic_vector(5 downto 0); -- Endereco do registrador RC522
        tx_data   : in  std_logic_vector(7 downto 0); -- Dado a escrever (se rw='0')
        rx_data   : out std_logic_vector(7 downto 0); -- Dado lido (se rw='1')
        busy      : out std_logic;
        done      : out std_logic;                    -- Pulso de 1 ciclo ao concluir
        -- Pinos Fisicos SPI (MFRC522)
        spi_cs_n  : out std_logic;                    -- SDA / NSS (Ativo Baixo)
        spi_sck   : out std_logic;                    -- SCK
        spi_mosi  : out std_logic;                    -- MOSI
        spi_miso  : in  std_logic                     -- MISO
    );
end entity spi_master;

architecture rtl of spi_master is

    type spi_state_type is (ST_IDLE, ST_CS_SETUP, ST_TRANSFER, ST_CS_HOLD, ST_DONE);
    signal state     : spi_state_type := ST_IDLE;

    signal clk_cnt   : integer range 0 to CLK_DIV := 0;
    signal sck_reg   : std_logic := '0';
    signal bit_cnt   : integer range 0 to 15 := 15;
    signal shift_tx  : std_logic_vector(15 downto 0) := (others => '0');
    signal shift_rx  : std_logic_vector(7 downto 0)  := (others => '0');
    signal miso_sync : std_logic_vector(1 downto 0)  := "00";

begin

    -- Sincronizador de 2 estagios para o pino MISO vindo do header GPIO
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            miso_sync <= "00";
        elsif rising_edge(clk) then
            miso_sync <= miso_sync(0) & spi_miso;
        end if;
    end process;

    -- Maquina de Estados do Transceptor SPI
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state    <= ST_IDLE;
            clk_cnt  <= 0;
            sck_reg  <= '0';
            bit_cnt  <= 15;
            shift_tx <= (others => '0');
            shift_rx <= (others => '0');
            rx_data  <= (others => '0');
            spi_cs_n <= '1';
            spi_mosi <= '0';
            busy     <= '0';
            done     <= '0';
        elsif rising_edge(clk) then
            done <= '0';

            case state is
                when ST_IDLE =>
                    spi_cs_n <= '1';
                    sck_reg  <= '0';
                    spi_mosi <= '0';
                    clk_cnt  <= 0;
                    if start = '1' then
                        -- Monta o frame de 16 bits: [RW & reg_addr(5:0) & '0'] & [tx_data]
                        if rw = '1' then
                            shift_tx <= ('1' & reg_addr & '0') & X"00";
                        else
                            shift_tx <= ('0' & reg_addr & '0') & tx_data;
                        end if;
                        bit_cnt  <= 15;
                        spi_cs_n <= '0';
                        busy     <= '1';
                        state    <= ST_CS_SETUP;
                    else
                        busy     <= '0';
                    end if;

                when ST_CS_SETUP =>
                    -- Tempo de setup do CS_N antes da primeira borda de SCK
                    spi_mosi <= shift_tx(15);
                    if clk_cnt = CLK_DIV - 1 then
                        clk_cnt <= 0;
                        state   <= ST_TRANSFER;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when ST_TRANSFER =>
                    if clk_cnt = CLK_DIV - 1 then
                        clk_cnt <= 0;
                        if sck_reg = '0' then
                            -- Borda de subida do SCK: Amostra MISO (Modo 0)
                            sck_reg <= '1';
                            if bit_cnt < 8 then
                                shift_rx <= shift_rx(6 downto 0) & miso_sync(1);
                            end if;
                        else
                            -- Borda de descida do SCK: Atualiza MOSI para o proximo bit
                            sck_reg <= '0';
                            if bit_cnt = 0 then
                                state <= ST_CS_HOLD;
                            else
                                bit_cnt  <= bit_cnt - 1;
                                spi_mosi <= shift_tx(bit_cnt - 1);
                            end if;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when ST_CS_HOLD =>
                    -- Mantem CS_N baixo por meio periodo antes de subir
                    if clk_cnt = CLK_DIV - 1 then
                        clk_cnt  <= 0;
                        spi_cs_n <= '1';
                        spi_mosi <= '0';
                        rx_data  <= shift_rx;
                        state    <= ST_DONE;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when ST_DONE =>
                    -- Tempo minimo de CS_N alto entre pacotes SPI
                    if clk_cnt = CLK_DIV - 1 then
                        clk_cnt <= 0;
                        busy    <= '0';
                        done    <= '1';
                        state   <= ST_IDLE;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;
            end case;
        end if;
    end process;

    spi_sck <= sck_reg;

end architecture rtl;

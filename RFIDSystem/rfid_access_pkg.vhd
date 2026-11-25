--------------------------------------------------------------------------------
-- Arquivo: rfid_access_pkg.vhd
-- Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
-- Placa Alvo: Terasic DE0-CV (Altera/Intel Cyclone V 5CEBA4F23C7)
-- Descricao: Pacote com definicoes da Maquina de Estados de Moore, lista
--            interna de IDs autorizados (ROM) e constantes de temporizacao.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package rfid_access_pkg is

    ----------------------------------------------------------------------------
    -- 1. Definicao dos Estados da Maquina de Moore (Conforme material da aula)
    ----------------------------------------------------------------------------
    -- S_AGUARDANDO  : Estado inicial de espera (Trava fechada, Display = "idLE")
    -- S_LENDO       : Captura do identificador do cartao RFID (Display = "rEAd")
    -- S_VERIFICANDO : Comparacao com a lista interna de IDs (Display = "ChEC")
    -- S_AUTORIZADO  : Acesso liberado, trava aberta e LED verde/OK (Display = "OPEn")
    -- S_NEGADO      : Acesso negado, trava fechada e LED erro (Display = "ErrO")
    -- S_BLOQUEADO   : Bloqueio de seguranca apos 3 erros seguidos (Display = "LOCd")
    type state_type is (
        S_AGUARDANDO,
        S_LENDO,
        S_VERIFICANDO,
        S_AUTORIZADO,
        S_NEGADO,
        S_BLOQUEADO
    );

    ----------------------------------------------------------------------------
    -- 2. Codigos de Mensagens para os Displays de 7 Segmentos (Saida de Moore)
    ----------------------------------------------------------------------------
    constant MSG_IDLE : std_logic_vector(2 downto 0) := "000"; -- Exibe "idLE"
    constant MSG_READ : std_logic_vector(2 downto 0) := "001"; -- Exibe "rEAd"
    constant MSG_CHEC : std_logic_vector(2 downto 0) := "010"; -- Exibe "ChEC"
    constant MSG_OPEN : std_logic_vector(2 downto 0) := "011"; -- Exibe "OPEn"
    constant MSG_ERRO : std_logic_vector(2 downto 0) := "100"; -- Exibe "ErrO"
    constant MSG_LOCD : std_logic_vector(2 downto 0) := "101"; -- Exibe "LOCd"

    ----------------------------------------------------------------------------
    -- 3. Lista Interna de Cartoes RFID Autorizados (32 bits = 4 bytes de UID)
    ----------------------------------------------------------------------------
    -- Nota: No modo de simulacao via Switches (SW[9]='1'), os 24 bits superiores
    -- sao preenchidos com X"000000" e o byte inferior vem de SW[7:0].
    -- No modo RFID-RC522 real (SW[9]='0'), o sistema compara tanto os 32 bits
    -- completos quanto permite cadastrar qualquer tag RFID na hora com KEY[2]!
    type uid_rom_type is array (0 to 3) of std_logic_vector(31 downto 0);

    constant AUTHORIZED_UIDS : uid_rom_type := (
        0 => X"000000A5", -- Cartao Autorizado 1 (SW[7:0] = "10100101" = 0xA5)
        1 => X"0000003C", -- Cartao Autorizado 2 (SW[7:0] = "00111100" = 0x3C)
        2 => X"DEADBEEF", -- Cartao Autorizado 3 (UID RFID 32-bit padrao)
        3 => X"12345678"  -- Cartao Autorizado 4 (UID RFID 32-bit padrao)
    );

    ----------------------------------------------------------------------------
    -- 4. Registradores e Comandos do Chip MFRC522 (RFID 13.56 MHz ISO14443A)
    ----------------------------------------------------------------------------
    -- Enderecos dos Registradores do MFRC522
    constant REG_COMMAND       : std_logic_vector(5 downto 0) := "000001"; -- 0x01
    constant REG_COM_IRQ       : std_logic_vector(5 downto 0) := "000100"; -- 0x04
    constant REG_ERROR         : std_logic_vector(5 downto 0) := "000110"; -- 0x06
    constant REG_STATUS2       : std_logic_vector(5 downto 0) := "001000"; -- 0x08
    constant REG_FIFO_DATA     : std_logic_vector(5 downto 0) := "001001"; -- 0x09
    constant REG_FIFO_LEVEL    : std_logic_vector(5 downto 0) := "001010"; -- 0x0A
    constant REG_CONTROL       : std_logic_vector(5 downto 0) := "001100"; -- 0x0C
    constant REG_BIT_FRAMING   : std_logic_vector(5 downto 0) := "001101"; -- 0x0D
    constant REG_COLL          : std_logic_vector(5 downto 0) := "001110"; -- 0x0E
    constant REG_MODE          : std_logic_vector(5 downto 0) := "010001"; -- 0x11
    constant REG_TX_MODE       : std_logic_vector(5 downto 0) := "010010"; -- 0x12
    constant REG_RX_MODE       : std_logic_vector(5 downto 0) := "010011"; -- 0x13
    constant REG_TX_CONTROL    : std_logic_vector(5 downto 0) := "010100"; -- 0x14
    constant REG_TX_ASK        : std_logic_vector(5 downto 0) := "010101"; -- 0x15
    constant REG_MOD_WIDTH     : std_logic_vector(5 downto 0) := "100100"; -- 0x24
    constant REG_RF_CFG        : std_logic_vector(5 downto 0) := "100110"; -- 0x26
    constant REG_T_MODE        : std_logic_vector(5 downto 0) := "101010"; -- 0x2A
    constant REG_T_PRESCALER   : std_logic_vector(5 downto 0) := "101011"; -- 0x2B
    constant REG_T_RELOAD_H    : std_logic_vector(5 downto 0) := "101100"; -- 0x2C
    constant REG_T_RELOAD_L    : std_logic_vector(5 downto 0) := "101101"; -- 0x2D
    constant REG_VERSION       : std_logic_vector(5 downto 0) := "110111"; -- 0x37

    -- Comandos internos do MFRC522 (CommandReg)
    constant PCD_IDLE          : std_logic_vector(7 downto 0) := X"00";
    constant PCD_TRANSCEIVE    : std_logic_vector(7 downto 0) := X"0C";
    constant PCD_RESETPHASE    : std_logic_vector(7 downto 0) := X"0F";

    -- Comandos ISO14443A enviados para o Cartao (PICC)
    constant PICC_REQIDL       : std_logic_vector(7 downto 0) := X"26";
    constant PICC_ANTICOLL_CL1 : std_logic_vector(7 downto 0) := X"93";

end package rfid_access_pkg;

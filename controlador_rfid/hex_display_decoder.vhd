--------------------------------------------------------------------------------
-- Arquivo: hex_display_decoder.vhd
-- Projeto: Sistema de Controle de Acesso com RFID e Estados de Autorizacao
-- Descricao: Controlador e decodificador para os 6 displays de 7 segmentos
--            Anodo Comum (ativos em nivel baixo '0') da placa DE0-CV (HEX5..HEX0).
--
-- Modos de Exibicao (controlado por show_uid_mode = SW[8]):
--   * show_uid_mode = '0' (Modo Padrao - Estados de Autorizacao):
--       - HEX3..HEX0 exibem a mensagem do estado atual da FSM de Moore:
--           MSG_IDLE ("000") -> "idLE" (Aguardando cartao)
--           MSG_READ ("001") -> "rEAd" (Lendo cartao)
--           MSG_CHEC ("010") -> "ChEC" (Verificando lista de autorizados)
--           MSG_OPEN ("011") -> "OPEn" (Acesso Autorizado!)
--           MSG_ERRO ("100") -> "ErrO" (Acesso Negado!)
--           MSG_LOCD ("101") -> "LOCd" (Bloqueado apos 3 erros!)
--       - HEX5..HEX4 exibem os 2 digitos hexadecimais inferiores (uid_in[7:0])
--         do ultimo cartao lido.
--   * show_uid_mode = '1' (Modo Inspecao de UID Hexadecimal):
--       - HEX5..HEX0 exibem os 6 digitos hexadecimais (24 bits inferiores:
--         uid_in[23:0]) do cartao RFID lido pelo RC522.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rfid_access_pkg.all;

entity hex_display_decoder is
    port (
        display_msg   : in  std_logic_vector(2 downto 0);
        uid_in        : in  std_logic_vector(31 downto 0);
        rc522_version : in  std_logic_vector(7 downto 0);
        show_uid_mode : in  std_logic; -- SW[8]: '0'=Status FSM, '1'=UID Hex completo (ou VersionReg se UID=0)
        hex0          : out std_logic_vector(6 downto 0);
        hex1          : out std_logic_vector(6 downto 0);
        hex2          : out std_logic_vector(6 downto 0);
        hex3          : out std_logic_vector(6 downto 0);
        hex4          : out std_logic_vector(6 downto 0);
        hex5          : out std_logic_vector(6 downto 0)
    );
end entity hex_display_decoder;

architecture rtl of hex_display_decoder is

    -- Constantes de caracteres em 7 segmentos (Ativo Baixo: "gfedcba")
    constant CHAR_BLANK : std_logic_vector(6 downto 0) := "1111111";
    constant CHAR_DASH  : std_logic_vector(6 downto 0) := "0111111"; -- '-'
    constant CHAR_I     : std_logic_vector(6 downto 0) := "1001111"; -- 'I'
    constant CHAR_D     : std_logic_vector(6 downto 0) := "0100001"; -- 'd'
    constant CHAR_L     : std_logic_vector(6 downto 0) := "1000111"; -- 'L'
    constant CHAR_E     : std_logic_vector(6 downto 0) := "0000110"; -- 'E'
    constant CHAR_R     : std_logic_vector(6 downto 0) := "0101111"; -- 'r'
    constant CHAR_A     : std_logic_vector(6 downto 0) := "0001000"; -- 'A'
    constant CHAR_C     : std_logic_vector(6 downto 0) := "1000110"; -- 'C'
    constant CHAR_H     : std_logic_vector(6 downto 0) := "0001011"; -- 'h'
    constant CHAR_O     : std_logic_vector(6 downto 0) := "1000000"; -- 'O'
    constant CHAR_P     : std_logic_vector(6 downto 0) := "0001100"; -- 'P'
    constant CHAR_N     : std_logic_vector(6 downto 0) := "0101011"; -- 'n'

    -- Funcao para converter um nibble (4 bits) em 7 segmentos hexadecimal (Ativo Baixo)
    function nibble_to_7seg(nib : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case nib is
            when X"0"   => return "1000000"; -- 0
            when X"1"   => return "1111001"; -- 1
            when X"2"   => return "0100100"; -- 2
            when X"3"   => return "0110000"; -- 3
            when X"4"   => return "0011001"; -- 4
            when X"5"   => return "0010010"; -- 5
            when X"6"   => return "0000010"; -- 6
            when X"7"   => return "1111000"; -- 7
            when X"8"   => return "0000000"; -- 8
            when X"9"   => return "0010000"; -- 9
            when X"A"   => return "0001000"; -- A
            when X"B"   => return "0000011"; -- b
            when X"C"   => return "1000110"; -- C
            when X"D"   => return "0100001"; -- d
            when X"E"   => return "0000110"; -- E
            when X"F"   => return "0001110"; -- F
            when others => return "1111111";
        end case;
    end function;

begin

    process(display_msg, uid_in, rc522_version, show_uid_mode)
    begin
        if show_uid_mode = '1' then
            if uid_in = X"00000000" then
                -- Sem cartao lido ainda: exibe "----XX" com o VersionReg (0x37) do RC522
                -- (0x91/0x92/0x88 = SPI OK | 0xFF ou 0x00 = falha na ligacao SPI)
                hex0 <= nibble_to_7seg(rc522_version(3 downto 0));
                hex1 <= nibble_to_7seg(rc522_version(7 downto 4));
                hex2 <= CHAR_DASH;
                hex3 <= CHAR_DASH;
                hex4 <= CHAR_DASH;
                hex5 <= CHAR_DASH;
            else
                -- Modo de Inspecao de UID: Exibe os 6 digitos hexadecimais do cartao
                hex0 <= nibble_to_7seg(uid_in(3 downto 0));
                hex1 <= nibble_to_7seg(uid_in(7 downto 4));
                hex2 <= nibble_to_7seg(uid_in(11 downto 8));
                hex3 <= nibble_to_7seg(uid_in(15 downto 12));
                hex4 <= nibble_to_7seg(uid_in(19 downto 16));
                hex5 <= nibble_to_7seg(uid_in(23 downto 20));
            end if;
        else
            -- HEX5 e HEX4 sempre mostram o byte inferior (ID curto) do ultimo cartao lido
            hex4 <= nibble_to_7seg(uid_in(3 downto 0));
            hex5 <= nibble_to_7seg(uid_in(7 downto 4));

            -- HEX3..HEX0 exibem a mensagem do estado de autorizacao da FSM de Moore
            case display_msg is
                when MSG_IDLE =>
                    -- Exibe "idLE"
                    hex3 <= CHAR_I;
                    hex2 <= CHAR_D;
                    hex1 <= CHAR_L;
                    hex0 <= CHAR_E;

                when MSG_READ =>
                    -- Exibe "rEAd"
                    hex3 <= CHAR_R;
                    hex2 <= CHAR_E;
                    hex1 <= CHAR_A;
                    hex0 <= CHAR_D;

                when MSG_CHEC =>
                    -- Exibe "ChEC"
                    hex3 <= CHAR_C;
                    hex2 <= CHAR_H;
                    hex1 <= CHAR_E;
                    hex0 <= CHAR_C;

                when MSG_OPEN =>
                    -- Exibe "OPEn" (Acesso Liberado)
                    hex3 <= CHAR_O;
                    hex2 <= CHAR_P;
                    hex1 <= CHAR_E;
                    hex0 <= CHAR_N;

                when MSG_ERRO =>
                    -- Exibe "ErrO" (Acesso Negado)
                    hex3 <= CHAR_E;
                    hex2 <= CHAR_R;
                    hex1 <= CHAR_R;
                    hex0 <= CHAR_O;

                when MSG_LOCD =>
                    -- Exibe "LOCd" (Sistema Bloqueado)
                    hex3 <= CHAR_L;
                    hex2 <= CHAR_O;
                    hex1 <= CHAR_C;
                    hex0 <= CHAR_D;

                when others =>
                    hex3 <= CHAR_DASH;
                    hex2 <= CHAR_DASH;
                    hex1 <= CHAR_DASH;
                    hex0 <= CHAR_DASH;
            end case;
        end if;
    end process;

end architecture rtl;

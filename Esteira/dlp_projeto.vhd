library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dlp_projeto is
    generic (
        C_CAPACIDADE           : integer := 79;
        L_LIMIAR               : integer := 60;
        CYCLES_PER_HALF_PERIOD : integer := 4  -- 25M p/ 1Hz em clk 50MHz
    );
    port (
        clk_50       : in  std_logic;
        rst          : in  std_logic;
        sentido      : in  std_logic; -- 0: Colocar peças; 1: Retirar peças
        pausa        : in  std_logic;
        modo         : in  std_logic_vector(1 downto 0);
        
        -- Indicadores em LEDs
        cheio        : out std_logic;
        vazio        : out std_logic;
        alerta       : out std_logic;
        erro         : out std_logic;
        sinal_div    : out std_logic;
        pulso_avanco : out std_logic;
        
        -- Displays de 7 segmentos (hex1: dezenas, hex0: unidades)
        hex1         : out std_logic_vector(6 downto 0);
        hex0         : out std_logic_vector(6 downto 0)
    );
end entity;

architecture Structural of dlp_projeto is

    -- Sinais internos
    signal sig_sinal_div    : std_logic;
    signal sig_pulso_avanco : std_logic;
    
    -- Registradores do Núcleo Sequencial
    signal reg_N    : integer range 0 to C_CAPACIDADE := 0;
    signal reg_P    : integer range 0 to C_CAPACIDADE := 0;
    signal reg_erro : std_logic := '0';
    
    -- Sinal multiplexado para os displays
    signal valor_para_display : integer range 0 to 79;
    signal dezena             : integer range 0 to 15;
    signal unidade            : integer range 0 to 15;

begin

    ------------------------------------------------------------------
    -- Instância do Divisor de Frequência
    ------------------------------------------------------------------
    U_DIVISOR : entity work.divisor_frequencia
		 generic map (
			  CLOCK_IN_HZ    => 50000000, -- 50 MHz (clock da placa)
			  TARGET_FREQ_HZ => 2,        -- 2 Hz (frequencia desejada)
			  H_SIMULATION   => 4         -- Para simulação rapida, mude para 4
		 )
		 port map (
			  clk_50       => clk_50,
			  rst          => rst,
			  pausa        => pausa,
			  sinal_div    => sig_sinal_div,
			  pulso_avanco => sig_pulso_avanco
		 );

    ------------------------------------------------------------------
    -- Núcleo Sequencial: Registradores N, P e Erro
    ------------------------------------------------------------------
    process(clk_50, rst)
    begin
        if rst = '1' then
            reg_N    <= 0;
            reg_P    <= 0;
            reg_erro <= '0';
        elsif rising_edge(clk_50) then
            if pausa = '1' then
                -- Pausa: preserva N, P e Erro
                reg_N    <= reg_N;
                reg_P    <= reg_P;
                reg_erro <= reg_erro;
            elsif sig_pulso_avanco = '1' then
                if sentido = '0' then
                    -- Tentar colocar peça
                    if reg_N < C_CAPACIDADE then
                        reg_N <= reg_N + 1;
                        -- Atualiza o pico maximo se ultrapassar o registro anterior
                        if (reg_N + 1) > reg_P then
                            reg_P <= reg_N + 1;
                        end if;
                    else
                        -- Transbordo: bandeja cheia
                        reg_erro <= '1';
                    end if;
                else
                    -- Tentar retirar peça
                    if reg_N > 0 then
                        reg_N <= reg_N - 1;
                    else
                        -- Subfluxo: bandeja vazia
                        reg_erro <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- Lógica Combinacional para Indicadores LEDs
    ------------------------------------------------------------------
    cheio  <= '1' when reg_N = C_CAPACIDADE else '0';
    vazio  <= '1' when reg_N = 0 else '0';
    alerta <= '1' when reg_N >= L_LIMIAR else '0';
    
    erro         <= reg_erro;
    sinal_div    <= sig_sinal_div;
    pulso_avanco <= sig_pulso_avanco;

    ------------------------------------------------------------------
    -- Instância do Seletor de Exibição
    ------------------------------------------------------------------
    U_SELETOR : entity work.seletor_exibicao
        generic map (
            C_CAPACIDADE => C_CAPACIDADE
        )
        port map (
            modo          => modo,
            N             => reg_N,
            P             => reg_P,
            valor_exibido => valor_para_display
        );

    ------------------------------------------------------------------
    -- Separação Decimal para Exibição (Dezena e Unidade)
    ------------------------------------------------------------------
    dezena  <= valor_para_display / 10;
    unidade <= valor_para_display mod 10;

    ------------------------------------------------------------------
    -- Instâncias dos Decodificadores de 7 Segmentos
    ------------------------------------------------------------------
    U_DEC_DEZENA : entity work.decodificador_7seg
        port map (
            bcd => dezena,
            seg => hex1
        );

    U_DEC_UNIDADE : entity work.decodificador_7seg
        port map (
            bcd => unidade,
            seg => hex0
        );

end architecture;
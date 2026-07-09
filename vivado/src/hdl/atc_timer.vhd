library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity atc_timer is
  port (
    CLK_I      : in  std_logic;
    RST_I      : in  std_logic;

    -- uart period in sys_clk cycles
    CONFIG_UART_I : in  std_logic_vector(31 downto 0);
    -- baud period in sys_clk cycles (independent)
    CONFIG_BAUD_I : in  std_logic_vector(31 downto 0);

    -- strobes
    UART_O     : out std_logic;
    BAUD_O     : out std_logic;

    -- ASIC clock, 50% duty cycle, period = UART period
    UCLK_O     : out std_logic
  );
end entity atc_timer;

architecture rtl of atc_timer is

  component timer is
    port (
      CLK_I      : in  std_logic;
      RST_I      : in  std_logic;
      CONFIG_I   : in  std_logic_vector(31 downto 0);
      STROBE_O   : out std_logic
    );
  end component;

  signal uart        : std_logic;
  signal baud        : std_logic;
  signal cfg_period  : unsigned(31 downto 0);
  signal half_period : unsigned(31 downto 0);
  signal uclk_cnt    : unsigned(31 downto 0) := (others => '0');
  signal uclk_reg    : std_logic := '0';

begin

  cfg_period  <= unsigned(CONFIG_UART_I);
  half_period <= '0' & cfg_period(31 downto 1);

  uart_timer: timer
    port map (
      CLK_I      => CLK_I,
      RST_I      => RST_I,
      CONFIG_I   => CONFIG_UART_I,
      STROBE_O   => uart
    );

  baud_timer: timer
    port map (
      CLK_I      => CLK_I,
      RST_I      => RST_I,
      CONFIG_I   => CONFIG_BAUD_I,
      STROBE_O   => baud
    );

  UART_O <= uart;
  BAUD_O <= baud;

  -- UCLK: high from uart strobe, low at half period
  process(CLK_I)
  begin
    if RST_I = '1' then
      uclk_cnt <= (others => '0');
      uclk_reg <= '0';
    elsif rising_edge(CLK_I) then
      if uart = '1' then
        uclk_reg <= '1';
        uclk_cnt <= (others => '0');
      elsif uclk_cnt = half_period - 1 then
        uclk_reg <= '0';
        uclk_cnt <= uclk_cnt + 1;
      else
        uclk_cnt <= uclk_cnt + 1;
      end if;
    end if;
  end process;

  UCLK_O <= uclk_reg;

end architecture rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.common.all;

entity atc_timer_tb is
end;

architecture behavioral of atc_timer_tb is

  component atc_timer is
    port (
      CLK_I      : in  std_logic;
      RST_I      : in  std_logic;
      CONFIG_UART_I : in  std_logic_vector(31 downto 0);
      CONFIG_BAUD_I : in  std_logic_vector(31 downto 0);
      UART_O     : out std_logic;
      BAUD_O     : out std_logic;
      UCLK_O     : out std_logic
    );
  end component;

  signal count       : integer := 0;
  signal show_output : std_logic := '0';

  signal clk         : std_logic := '0';
  signal rst         : std_logic := '1';
  signal uart_cfg    : std_logic_vector(31 downto 0) := x"00000004";
  signal baud_cfg    : std_logic_vector(31 downto 0) := x"00000008";
  signal uart        : std_logic;
  signal baud        : std_logic;
  signal uclk        : std_logic;

begin

  uut: atc_timer port map (
    CLK_I      => clk,
    RST_I      => rst,
    CONFIG_UART_I => uart_cfg,
    CONFIG_BAUD_I => baud_cfg,
    UART_O     => uart,
    BAUD_O     => baud,
    UCLK_O     => uclk
  );

  -- clock: 10 ns period
  clk <= not clk after 5 ns;

  -- reset: deassert after 2 cycles
  rst <= '0' after 21 ns;

  -- show output after reset
  show_output <= '1' after 21 ns;

  -- count clock cycles
  count_process : process
  begin
    wait until rising_edge(clk);
    count <= count + 1;
  end process;

  output_process : process
    variable l : line;
  begin
    wait for 10 ns;
    if show_output = '1' then
      write  (l, String'("c: "));
      write  (l, count, left, 5);
      write  (l, String'(" clk: "));
      write  (l, clk);
      write  (l, String'("| uart: "));
      write  (l, uart);
      write  (l, String'(" baud: "));
      write  (l, baud);
      write  (l, String'(" uclk: "));
      write  (l, uclk);
      if rst = '1' then
        write (l, String'(" (RESET)"));
      end if;
      writeline(output, l);
    end if;
  end process;

end;

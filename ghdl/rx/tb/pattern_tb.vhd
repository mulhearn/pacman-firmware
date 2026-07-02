library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;

entity pattern_tb is
end pattern_tb;

architecture behaviour of pattern_tb is
  component pattern is
    port (
      CLK_I           : in  std_logic;
      RST_I           : in  std_logic;
      BAUD_SYNC_I     : in  std_logic;
      PAYLOAD_I       : in  std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
      CONFIG_I        : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DELAY_I         : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PATTERN_O       : out std_logic;
      STATUS_O        : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
      );
  end component;

  signal count      : integer := 0;
  signal tstep_ns   : integer := 10;
  signal clk        : std_logic;
  signal rst        : std_logic;
  signal baud       : std_logic;
  signal tx         : std_logic;
  signal status     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  signal show_output : std_logic := '0';

begin
  uut: pattern port map (
    CLK_I       => clk,
    RST_I       => rst,
    BAUD_SYNC_I => baud,
    PAYLOAD_I   => x"FFFF0000AAAAAAAA",
    CONFIG_I    => x"00000101",
    DELAY_I     => x"00000002",
    PATTERN_O   => tx,
    STATUS_O    => status
  );

  clk_process : process
  begin
    count <= count + 1;
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  rst_process : process
  begin
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;

  baud_process : process
  begin
    baud <= '1';
    wait for 10 ns;
    baud <= '0';
    wait for 90 ns;
  end process;

  show_process : process
  begin
    show_output <= '1';
    wait;
  end process;

  output_process : process
    variable l     : line;
    variable start : std_logic := '0';
    variable stop  : std_logic := '0';
  begin
    wait for 10 ns;

    start := status(0);
    stop  := status(1);

    if (show_output = '1') then
      write (l, String'("c: "));
      write (l, count, left, 5);
      write (l, String'(" clk: "));
      write (l, clk);
      write (l, String'(" bd: "));
      write (l, baud);
      write (l, String'(" tx: "));
      write (l, tx);
      write (l, String'(" | peek: "));
      write (l, status(8));
      write (l, String'(" s: "));
      write (l, start);
      write (l, String'(" e: "));
      write (l, stop);
      if (start = '1') then
        write (l, String'(" --- "));
      end if;
      if (stop = '1') then
        write (l, String'(" *** "));
      end if;
      if (rst = '1') then
        write (l, String'(" (RESET)"));
      end if;
      writeline(output, l);
    end if;
  end process;

end behaviour;

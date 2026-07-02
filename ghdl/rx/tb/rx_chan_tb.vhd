library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;

--  Defines a testbench (without any ports)
entity rx_chan_tb is
end rx_chan_tb;

architecture behaviour of rx_chan_tb is
  component rx_chan is
    port (
      -- clock and active-high reset
      CLK_I          : in std_logic;
      RST_I          : in std_logic;
      -- sync the start of each baud period:
      BAUD_SYNC_I    : in std_logic;
      CONFIG_I       : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      STATUS_O       : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DATA_O         : out  std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
      TIMESTAMP_O    : out  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
      VALID_O        : out  std_logic;
      READY_I        : in std_logic;
      RX_I           : in std_logic;
      LOOPBACK_I     : in std_logic;
      PATTERN_I      : in std_logic;
      EMUL_I         : in std_logic;
      TIMESTAMP_I    : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
      DEBUG_O       : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
      );
  end component;

  signal count      : integer := 0;
  signal tstep_ns   : integer := 10;
  signal clk        : std_logic;
  signal rst        : std_logic;
  signal baud       : std_logic;
  signal status     : std_logic_vector(C_RB_DATA_WIDTH-1  downto 0);
  signal data       : std_logic_vector(C_UART_DATA_WIDTH-1 DOWNTO 0);
  signal tstamp     : std_logic_vector(C_UART_DATA_WIDTH-1 DOWNTO 0);
  signal rx         : std_logic := '1';
  signal valid      : std_logic;
  signal ready      : std_logic;

  signal show_output : std_logic := '0';

begin
  uut: rx_chan port map (
    CLK_I       => clk,
    RST_I       => rst,
    BAUD_SYNC_I => baud,
    CONFIG_I    => x"00000101",
    DATA_O      => data,
    TIMESTAMP_O => tstamp,
    VALID_O     => valid,
    READY_I     => ready,
    RX_I        => rx,
    LOOPBACK_I  => '1',
    PATTERN_I   => '1',
    EMUL_I      => '1',
    TIMESTAMP_I => x"0000000012345678",
    DEBUG_O     => status
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

  ready_process : process
  begin
    ready <= '0';
    wait until count=753;
    ready <='1';
    wait for 100 ns;
    ready <='0';
    wait;
  end process;

  rx_process : process
    variable i      : integer := 0;
    variable rxdata : std_logic_vector(159 downto 0) := x"FF33332222000011117FFF33331111000011117F";
  begin
    wait until rising_edge(baud);
    wait for 1 ns;
    if (i<160) then
      rx <= rxdata(i);
      i := i+1;
    else
      rx <= '1';
      wait for 500 ns;
      i := 0;
    end if;
  end process;

  show_process : process
  begin
    tstep_ns <= 100;
    show_output <= '1';
    wait;
  end process;

  output_process : process
    variable l : line;
    variable start   : std_logic := '0';
    variable update  : std_logic := '0';
    variable lost    : std_logic := '0';
  begin
    wait until status(0)='1';
    wait for 1 ns;
    wait for 10 ns;

    start  := status(4);
    update := status(5);
    lost   := status(6);

    if (show_output='1') then
      write (l, String'("c: "));
      write (l, count, left, 5);
      write  (l, String'("clk: "));
      write  (l, clk);
      write  (l, String'(" bd: "));
      write  (l, baud);
      write  (l, String'(" en: "));
      write  (l, status(0));
      write  (l, String'(" b: "));
      write (l, status(1));
      write  (l, String'(" v: "));
      write (l, status(2));
      write (l, valid);
      write  (l, String'(" r: "));
      write (l, status(3));
      write (l, ready);
      write  (l, String'(" s: "));
      write (l, start);
      write  (l, String'(" u: "));
      write (l, update);
      write  (l, String'(" l: "));
      write (l, lost);
      write  (l, String'(" | d: 0x"));
      hwrite (l, data);
      --write  (l, String'(" | ts: 0x"));
      --hwrite (l, tstamp);
      write  (l, String'(" | rx: "));
      write  (l, rx);
      write  (l, String'(" | sel: "));
      write  (l, status(8));
      if (start = '1') then
        write (l, String'(" --- "));
      end if;
      if (update = '1') then
        write (l, String'(" *** "));
      end if;
      if (lost = '1') then
        write (l, String'(" !!! "));
      end if;
      if (rst = '1') then
        write (l, String'(" (RESET)"));
      end if;
      writeline(output, l);
    end if;
  end process;



end behaviour;


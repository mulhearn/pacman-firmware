-- Diagram testbench (make waveforms):  rx_chan receiving three back-to-back UART frames, for the firmware
-- description (rx_chan_start.pdf, rx_chan_frames.pdf).  Default configuration 000A1104 (period 10 clocks, edge
-- mode, input RX_I, phase 4);  BAUD every 10 clocks.  READY is given once, after the first word:  the second
-- word stays valid, the third is lost.  The input is asynchronous to the clock (edges at odd times).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

entity rx_chan_diagram_tb is
end rx_chan_diagram_tb;

architecture behaviour of rx_chan_diagram_tb is
  signal clk    : std_logic := '1';
  signal rst    : std_logic := '1';
  signal baud   : std_logic := '0';
  signal rx     : std_logic := '1';
  signal valid  : std_logic;
  signal ready  : std_logic := '0';
  signal data   : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  signal ts_in  : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0) := (others => '0');
  signal ts_out : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal debug  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  -- picked out of the (unregistered) status bits, see rx_chan.vhd
  signal state     : std_logic_vector(1 downto 0);
  signal sample_en : std_logic;
  signal vote      : std_logic;
  signal update    : std_logic;
  signal lost      : std_logic;
  signal start     : std_logic;
  signal taps      : std_logic_vector(2 downto 0);
  signal phase     : std_logic_vector(7 downto 0);

  constant BIT_T : time := 100 ns;
begin
  state     <= debug(1 downto 0);
  start     <= debug(4);
  update    <= debug(5);
  lost      <= debug(6);
  sample_en <= debug(10);
  taps      <= debug(14 downto 12);
  vote      <= debug(15);
  phase     <= debug(31 downto 24);

  uut: entity work.rx_chan port map (
    CLK_I       => clk,
    RST_I       => rst,
    BAUD_I      => baud,
    CONFIG_I    => x"000A1104",
    STATUS_O    => open,
    DATA_O      => data,
    TIMESTAMP_O => ts_out,
    VALID_O     => valid,
    READY_I     => ready,
    RX_I        => rx,
    LOOPBACK_I  => '1',
    PATTERN_I   => '1',
    EMUL_I      => '1',
    TIMESTAMP_I => ts_in,
    DEBUG_O     => debug
  );

  clk <= not clk after 5 ns;
  rst <= '0' after 20 ns;

  -- BAUD:  one clock in ten;  the timestamp counts BAUD strobes (as the timing unit's does UART strobes)
  process
  begin
    wait until rising_edge(clk);
    for i in 1 to 9 loop wait until rising_edge(clk); end loop;
    loop
      wait for 1 ns;
      baud <= '1';
      ts_in <= std_logic_vector(unsigned(ts_in) + 1);
      wait until rising_edge(clk);
      wait for 1 ns;
      baud <= '0';
      for i in 1 to 9 loop wait until rising_edge(clk); end loop;
    end loop;
  end process;

  process
    procedure send(w : std_logic_vector(63 downto 0)) is
    begin
      rx <= '0';
      wait for BIT_T;
      for i in 0 to 63 loop
        rx <= w(i);
        wait for BIT_T;
      end loop;
      rx <= '1';
      wait for BIT_T;
    end procedure;
  begin
    wait for 1033 ns;
    send(x"1111222233334444");
    wait for 2 * BIT_T;
    send(x"5555666677778888");
    wait for 2 * BIT_T;
    send(x"9999AAAABBBBCCCC");
    wait;
  end process;

  -- READY once, a while after the first word is valid
  process
  begin
    wait until valid = '1';
    wait for 1003 ns;
    wait until falling_edge(clk);
    ready <= '1';
    wait until falling_edge(clk);
    ready <= '0';
    wait;
  end process;
end behaviour;

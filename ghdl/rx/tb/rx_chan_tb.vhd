----------------------------------------------------------------------------------------------------
-- rx_chan_tb:  RX UART channel test bench
--
-- One RX UART channel fed two 64-bit words (repeated), READY high only once:  word 1 is taken, word
-- 2 waits, word 1 again is lost ((LOST) on the third word).  The data shifts in bit by bit,
-- (UPDATE) at each word.
--
-- Shows one line per sample point: state, v: valid, r: ready, ph = phase, d = the received data, rx
-- = the input and the three taps, vden = vote, dissent, sample enable, noise;  (START) a start bit,
-- (UPDATE) a word complete, (LOST) a word overwritten before it was taken.
--
-- Scenario: period 0A, edge mode, input RX_I, phase 4  -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity rx_chan_tb is
end rx_chan_tb;

architecture behaviour of rx_chan_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal baud   : std_logic;
  signal status : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal data   : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  signal tstamp : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal rx     : std_logic := '1';
  signal valid  : std_logic;
  signal ready  : std_logic;
  signal config : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  -- the channel configuration (alternatives in comments):
  config <= x"000A1104";                                        -- period 0A, edge, RX_I, phase 4
  --config <= x"000A2104";                                      -- period 0A, fixed, RX_I, phase 4
  --config <= x"000A5108";                                      -- edge, phase 8 (noisy), flag 0
  --config <= x"000A0104";                                      -- mode off:  nothing received

  uut: entity work.rx_chan port map (
    CLK_I       => clk,
    RST_I       => rst,
    BAUD_I      => baud,
    CONFIG_I    => config,
    DATA_O      => data,
    TIMESTAMP_O => tstamp,
    VALID_O     => valid,
    READY_I     => ready,
    RX_I        => rx,
    RX_SYNC_O   => open,
    LOOPBACK_I  => '1',
    PATTERN_I   => '1',
    EMUL_I      => '1',
    TIMESTAMP_I => x"0000000012345678",
    DEBUG_O     => status,
    STATUS_O    => open
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
    note("READY high for 10 clocks:  word 1 is taken");
    ready <='1';
    wait for 100 ns;
    ready <='0';
    wait;
  end process;

  -- LSB first:  7F (idle, start bit), word 1 (3333111100001111), FF 7F, word 2 (3333222200001111), FF
  rx_process : process
    constant rxdata : std_logic_vector(159 downto 0) := x"FF33332222000011117FFF33331111000011117F";
  begin
    fold(true);
    loop
      note("sending word 1 and word 2");
      for i in 0 to 159 loop
        wait until rising_edge(baud);
        wait for 1 ns;
        rx <= rxdata(i);
      end loop;
      wait until rising_edge(baud);
      wait for 1 ns;
      rx <= '1';
      wait for 500 ns;
    end loop;
  end process;

  -- print any folded lines still pending, just before the Makefile's --stop-time=30us
  end_process : process
  begin
    wait for 29995 ns;
    fold(false);
    wait;
  end process;

  -- at each sample point:  state, valid/ready, phase, data, rx taps, vote/dissent/sample/noise, markers
  -- (status bits:  rx_chan.vhd, end of file)
  output_process : process
    type names_t is array (0 to 3) of string(1 to 5);
    constant STATE : names_t := ("IDLE ", "FIRST", "DATA ", "STOP ");
  begin
    wait until status(10)='1';
    wait for 11 ns;
    strip(count, STATE(to_integer(unsigned(status(1 downto 0))))
      & " v: " & bits(valid) & " r: " & bits(ready)
      & " | ph " & hex(status(31 downto 24))
      & " | d " & hex(data)
      & " | rx " & bits(rx & status(12) & status(13) & status(14))
      & " | vden " & bits(status(15) & status(11) & status(10) & status(8))
      & mark(status(4), "(START)") & mark(status(5), "(UPDATE)") & mark(status(6), "(LOST)") & mark(rst, "(RESET)"));
  end process;
end behaviour;

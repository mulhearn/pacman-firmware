----------------------------------------------------------------------------------------------------
-- tx_chan_tb:  TX UART channel test bench
--
-- One UART TX channel, two words handed over (VALID/READY):  the second word waits (VALID, no
-- READY) until the first frame is out;  both frames decode.
--
-- Shows one line per baud period, on the baud tick: state, v: valid, r: ready, tx;  (START) start
-- flag, (BEAT) word taken;  "frame sent" lines decode tx like a UART receiver.
--
-- Scenario: baud period 3 clocks, no delay, phase 2;  words 00FF00FF00FF00FF, then AAAAAAAAAAAAAAAA
-- -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity tx_chan_tb is
end tx_chan_tb;

architecture behaviour of tx_chan_tb is
  signal count    : integer := 0;
  signal clk      : std_logic;
  signal rst      : std_logic;
  signal status   : std_logic_vector(31 downto 0);
  signal status_z : std_logic_vector(31 downto 0);
  signal valid    : std_logic := '0';
  signal ready    : std_logic;
  signal tx       : std_logic;
  signal baud     : std_logic;
  signal data     : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  signal config : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  -- the channel configuration (alternatives in comments):
  config <= x"00000002";                                        -- no delay, phase 2
  --config <= x"00020002";                                      -- delay 2 bits, phase 2
  --config <= x"00000001";                                      -- no delay, phase 1

  uut: entity work.tx_chan port map (
    CLK_I    => clk,
    RST_I    => rst,
    BAUD_I   => baud,
    CONFIG_I => config,
    DEBUG_O  => status,
    STATUS_O => status_z,
    DATA_I   => data,
    VALID_I  => valid,
    READY_O  => ready,
    TX_O     => tx
  );

  rst_process : process
  begin
    rst <= '1';
    wait for 10 ns;
    rst <= '0';
    wait;
  end process;

  clk_process : process
  begin
    count <= count + 1;
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  baud_process : process
  begin
    baud <= '1';
    wait for 10 ns;
    baud <= '0';
    wait for 20 ns;
  end process;

  tx_process : process
  begin
    data  <= (others => '0');
    valid <= '0';
    wait for 21 ns;
    note("VALID:  word 00FF00FF00FF00FF");
    data  <= x"00FF00FF00FF00FF";
    valid <= '1';
    wait until ((rising_edge(clk)) and (ready='1'));
    wait for 1 ns;
    data  <= (others => '0');
    valid <= '0';
    wait for 40 ns;
    note("VALID:  word AAAAAAAAAAAAAAAA (waits for the first frame)");
    valid <= '1';
    data  <= x"AAAAAAAAAAAAAAAA";
    wait until ((rising_edge(clk)) and (ready='1'));
    wait for 1 ns;
    data  <= (others => '0');
    valid <= '0';
    wait;
  end process;

  output_process : process
    type names_t is array (0 to 3) of string(1 to 5);
    constant STATE : names_t := ("IDLE ", "SHIFT", "STOP ", "DELAY");
    variable s, b  : std_logic := '0';                         -- start flag, beat, seen since the last line
    variable n     : integer := -1;                             -- bits of the frame so far (-1: idle)
    variable frame : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  begin
    fold(true);
    while count < 500 loop
      wait for 10 ns;
      s := s or status(0);
      b := b or (valid and ready);
      if baud = '1' then
        -- decode like a UART receiver:  start bit, 64 data bits (LSB first), stop bit
        if n = -1 and tx = '0' then
          n := 0;
        elsif n >= 0 and n < C_UART_DATA_WIDTH then
          frame := tx & frame(C_UART_DATA_WIDTH-1 downto 1);
          n := n + 1;
        elsif n = C_UART_DATA_WIDTH then
          note("frame sent:  " & hex(frame) & mark(not tx, "(no stop bit)"));
          n := -1;
        end if;
        strip(count, STATE(to_integer(unsigned(status_z(5 downto 4)))) & " v: " & bits(valid) & " r: " & bits(ready) & " | tx " & bits(tx)
          & mark(s, "(START)") & mark(b, "(BEAT)") & mark(rst, "(RESET)"));
        s := '0';
        b := '0';
      end if;
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

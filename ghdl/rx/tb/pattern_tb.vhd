----------------------------------------------------------------------------------------------------
-- pattern_tb:  test pattern generator test bench
--
-- Shows one line per baud period (10 clocks), sampled mid-bit: tx, peek = the registered tx in
-- STATUS_O; and the frame that a UART receiver would receive.
--
-- Scenario: payload FFFF0000AAAAAAAA, delay 2:  phase 1, -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity pattern_tb is
end pattern_tb;

architecture behaviour of pattern_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal baud   : std_logic;
  signal tx     : std_logic;
  signal status : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal payload : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  signal config  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal delay   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  -- the pattern configuration (alternatives in comments):
  payload <= x"FFFF0000AAAAAAAA";
  --payload <= x"0123456789ABCDEF";                             -- bit order easy to see
  config  <= x"00000101";                                       -- mode on, phase 1
  --config  <= x"00000105";                                     -- mode on, phase 5
  --config  <= x"00000001";                                     -- mode off:  no frames
  delay   <= x"00000002";                                       -- 2 idle bits
  --delay   <= x"00000000";                                     -- no delay:  back to back
  --delay   <= x"00000005";                                     -- 5 idle bits

  uut: entity work.pattern port map (
    CLK_I       => clk,
    RST_I       => rst,
    BAUD_I      => baud,
    PAYLOAD_I   => payload,
    CONFIG_I    => config,
    DELAY_I     => delay,
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

  output_process : process
    variable s, e  : std_logic := '0';                        -- flags seen since the last line
    variable n     : integer := -1;                            -- bits received in this frame (-1: idle)
    variable frame : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  begin
    fold(true);
    while count < 1400 loop
      wait until rising_edge(clk);
      wait for 1 ns;
      s := s or status(0);
      e := e or status(1);
      if count mod 10 = 0 then                                 -- mid-bit
        -- decode like a UART receiver:  start bit, 64 data bits (LSB first), stop bit
        if n = -1 and tx = '0' then
          n := 0;
        elsif n >= 0 and n < C_UART_DATA_WIDTH then
          frame := tx & frame(C_UART_DATA_WIDTH-1 downto 1);
          n := n + 1;
        elsif n = C_UART_DATA_WIDTH then
          note("frame received:  " & hex(frame) & mark(not tx, "(no stop bit)"));
          n := -1;
        end if;
        strip(count, " tx " & bits(tx) & " | peek " & bits(status(8))
              & mark(s, "(START)") & mark(e, "(STOP)") & mark(rst, "(RESET)"));
        s := '0';
        e := '0';
      end if;
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

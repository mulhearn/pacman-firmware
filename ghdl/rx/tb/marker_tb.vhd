----------------------------------------------------------------------------------------------------
-- marker_tb:  marker source test bench
--
-- The timestamp is latched with VALID on a marker, held until READY (one beat), then VALID is
-- cleared.
--
-- Shows one line per clock: v: valid, r: ready, ts = the timestamp out, (BEAT) when taken.
--
-- Scenario: marker source enabled  -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity marker_tb is
end marker_tb;

architecture behaviour of marker_tb is
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal tstamp    : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal tstamp_in : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0) := (others => '0');
  signal valid     : std_logic;
  signal ready     : std_logic;
  signal marker    : std_logic;
  signal en : std_logic;
begin
  -- the marker configuration (alternatives in comments):
  en <= '1';                                                    -- enabled
  --en <= '0';                                                  -- disabled:  markers ignored

  tstamp_in <= std_logic_vector(to_unsigned(count, tstamp_in'length));

  uut: entity work.marker port map (
    CLK_I       => clk,
    RST_I       => rst,
    EN_I        => en,
    TIMESTAMP_O => tstamp,
    VALID_O     => valid,
    READY_I     => ready,
    MARKER_I    => marker,
    TIMESTAMP_I => tstamp_in,
    DEBUG_O     => open
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

  ready_process : process
  begin
    ready <= '0';
    wait until (count=15);
    wait for 1 ns;
    note("READY high from here on");
    ready <='1';
    wait;
  end process;

  marker_process : process
  begin
    marker <= '0';
    wait until (count=8);
    wait for 1 ns;
    note("MARKER pulse (one clock)");
    marker <='1';
    wait for 10 ns;
    marker <='0';
    wait;
  end process;

  -- one line per clock up to clock 34:  valid, ready, timestamp out;  (BEAT) when taken (VALID and READY)
  output_process : process
  begin
    fold(true);
    wait for 10 ns;
    if count < 35 then
      strip(count, "v: " & bits(valid) & " r: " & bits(ready) & " | ts " & hex(tstamp)
            & mark(valid and ready, "(BEAT)") & mark(rst, "(RESET)"));
    else
      fold(false);
      wait;
    end if;
  end process;
end behaviour;

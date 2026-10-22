----------------------------------------------------------------------------------------------------
-- heartbeat_tb:  heartbeat source test bench
--
-- Every CONFIG clocks the heartbeat raises VALID with the timestamp, held until READY;  while READY
-- is low, VALID waits and the timestamp stays frozen.
--
-- Shows one line per clock: v: valid, r: ready, ts = the timestamp out, (BEAT) when a heartbeat is
-- taken.
--
-- Scenario: heartbeat every 8 clocks, timestamp input = clock count, READY high from clock 15  --
-- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity heartbeat_tb is
end heartbeat_tb;

architecture behaviour of heartbeat_tb is
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal tstamp    : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal tstamp_in : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0) := (others => '0');
  signal valid     : std_logic;
  signal ready     : std_logic;
  signal en     : std_logic;
  signal config : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  -- the heartbeat configuration (alternatives in comments):
  en     <= '1';                                                -- enabled
  --en     <= '0';                                              -- disabled:  no heartbeats
  config <= x"00000008";                                        -- a heartbeat every 8 clocks
  --config <= x"00000004";                                      -- a heartbeat every 4 clocks

  tstamp_in <= std_logic_vector(to_unsigned(count, tstamp_in'length));

  uut: entity work.heartbeat port map (
    CLK_I       => clk,
    RST_I       => rst,
    EN_I        => en,
    CONFIG_I    => config,
    TIMESTAMP_O => tstamp,
    VALID_O     => valid,
    READY_I     => ready,
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

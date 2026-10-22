----------------------------------------------------------------------------------------------------
-- rollover_tb:  rollover source test bench
--
-- When the low 32 timestamp bits reach CONFIG the rollover source raises VALID with the timestamp,
-- held until READY, then once per wrap of the timestamp input.
--
-- Shows one line per clock: ts in = the timestamp input, v: valid, r: ready, ts = the timestamp
-- out, (BEAT) when taken.
--
-- Scenario: rollover at 3, timestamp input = clock count mod 16, READY from clock 15  --
-- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity rollover_tb is
end rollover_tb;

architecture behaviour of rollover_tb is
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
  -- the rollover configuration (alternatives in comments):
  en     <= '1';                                                -- enabled
  --en     <= '0';                                              -- disabled:  no rollover
  config <= x"00000003";                                        -- rollover at timestamp 3
  --config <= x"0000000A";                                      -- rollover at timestamp 0A

  ts_process: process
  begin
    tstamp_in <= std_logic_vector(to_unsigned(count mod 16, tstamp_in'length));
    wait for 10 ns;
  end process;

  uut: entity work.rollover port map (
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
      strip(count, "ts in " & hex(tstamp_in(3 downto 0)) & " | v: " & bits(valid) & " r: " & bits(ready) & " | ts " & hex(tstamp)
        & mark(valid and ready, "(BEAT)") & mark(rst, "(RESET)"));
    else
      fold(false);
      wait;
    end if;
  end process;
end behaviour;

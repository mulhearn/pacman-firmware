----------------------------------------------------------------------------------------------------
-- rising_edge_detect_tb:  rising edge detector test bench
--
-- Rising edge detection on an input synchronous to UCLK (100 ns), with a 4-cycle debounce.
--
-- Shows one line per clock: uclk | sig = the input, update;  (UPDATE) once per accepted edge.
--
-- Scenario: rising edges;  the input high 100 ns, low 100, high 200, low 100, high 200  --
-- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity rising_edge_detect_tb is
end rising_edge_detect_tb;

architecture behaviour of rising_edge_detect_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal uclk   : std_logic;
  signal sig   : std_logic := '0';
  signal update : std_logic := '0';
  signal invert : std_logic;
begin
  -- the detector configuration (alternatives in comments):
  invert <= '0';                                                -- rising edges
  --invert <= '1';                                              -- falling edges

  dut0: entity work.rising_edge_detect
    generic map (
      DEBOUNCE_CYCLES => 4
    )
    port map (
      CLK_I          => uclk,
      RST_I          => rst,
      SIGNAL_I       => sig,
      INVERT_I       => invert,
      UPDATE_O       => update
    );

  signal_process : process
  begin
    sig <= '0';
    wait for 160 ns;
    sig <= '1'; wait for 100 ns;
    sig <= '0'; wait for 100 ns;
    sig <= '1'; wait for 200 ns;
    sig <= '0'; wait for 100 ns;
    sig <= '1'; wait for 200 ns;
    sig <= '0';
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

  rst_process : process
  begin
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;

  uclk_process : process
  begin
    uclk <= '1';
    wait for 50 ns;
    uclk <= '0';
    wait for 50 ns;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 120 loop
      wait for 10 ns;
      strip(count, "uclk " & bits(uclk) & " | sig " & bits(sig) & " update " & bits(update)
        & mark(update, "(UPDATE)") & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

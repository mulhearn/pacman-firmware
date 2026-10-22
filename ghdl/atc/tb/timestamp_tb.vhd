----------------------------------------------------------------------------------------------------
-- timestamp_tb:  timestamp test bench
--
-- The timestamp counts the ENABLE strobes, stepping one clock after each.
--
-- Shows one line per clock: e = enable | timestamp.
--
-- Scenario: one ENABLE strobe every 3 clocks
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity timestamp_tb is
end timestamp_tb;

architecture behaviour of timestamp_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal enable : std_logic;
  signal ts     : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
begin
  uut: entity work.timestamp port map (
    CLK_I       => clk,
    RST_I       => rst,
    SYNC_I      => '0',
    ENABLE_I    => enable,
    TIMESTAMP_O => ts
  );

  rst_process : process
  begin
    rst <= '1';
    wait for 20 ns;
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

  enable_process : process
  begin
    wait for 1 ns;
    enable <= '1';
    wait for 10 ns;
    enable <= '0';
    wait for 20 ns;
  end process;

  output_process : process
  begin
    wait for 10 ns;
    strip(count, "e " & bits(enable) & " | timestamp " & hex(ts) & mark(rst, "(RESET)"));
  end process;
end behaviour;

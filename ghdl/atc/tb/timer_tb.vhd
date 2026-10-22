----------------------------------------------------------------------------------------------------
-- timer_tb:  timer test bench
--
-- A strobe every CONFIG clocks.
--
-- Shows one line per clock: strobe, (STROBE) on each strobe.
--
-- Scenario: a strobe every 3 clocks  -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity timer_tb is
end;

architecture behavioral of timer_tb is
  signal count  : integer := 0;
  signal clk    : std_logic := '0';
  signal rst    : std_logic := '1';
  signal strobe : std_logic;
  signal config : std_logic_vector(31 downto 0);
begin
  -- the timer configuration (alternatives in comments):
  config <= x"00000003";                                        -- a strobe every 3 clocks
  --config <= x"00000005";                                      -- a strobe every 5 clocks
  --config <= x"00000001";                                      -- a strobe every clock

  uut: entity work.timer port map (
    CLK_I    => clk,
    RST_I    => rst,
    CONFIG_I => config,
    STROBE_O => strobe
  );

  clk <= not clk after 5 ns;
  rst <= '0' after 21 ns;

  count_process : process
  begin
    wait until rising_edge(clk);
    count <= count + 1;
  end process;

  output_process : process
  begin
    wait for 21 ns;
    loop
      wait for 10 ns;
      strip(count, "strobe " & bits(strobe) & mark(strobe, "(STROBE)"));
    end loop;
  end process;
end;

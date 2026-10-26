----------------------------------------------------------------------------------------------------
-- adc_cmp_tb:  ADC comparator test bench
--
-- The level goes high when the data reaches THRESH + SWING, low when it falls to THRESH - SWING,
-- and holds in between;  it lags the data by one clock.
--
-- Shows one line per clock: data (hex) | level.
--
-- Scenario: THRESH 0x010, SWING 4;  the data up from 0x008 to 0x018 and back, by 2 per clock
-- -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity adc_cmp_tb is
end adc_cmp_tb;

architecture behaviour of adc_cmp_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal data   : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal thresh : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal swing  : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal level  : std_logic;
begin
  -- the comparator configuration (alternatives in comments):
  thresh <= x"010";
  swing  <= x"004";                                             -- high from 0x014, low from 0x00C
  --swing  <= x"000";                                           -- no hysteresis
  --swing  <= x"020";                                           -- clipped:  low only at 0x000

  uut: entity work.adc_cmp port map (
    CLK_I    => clk,
    RST_I    => rst,
    DATA_I   => data,
    THRESH_I => thresh,
    SWING_I  => swing,
    LEVEL_O  => level
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

  -- a triangle, changed on falling edges
  data_process : process
  begin
    data <= x"008";
    wait for 25 ns;
    for i in 1 to 8 loop
      data <= std_logic_vector(unsigned(data) + 2);
      wait for 10 ns;
    end loop;
    for i in 1 to 8 loop
      data <= std_logic_vector(unsigned(data) - 2);
      wait for 10 ns;
    end loop;
    wait;
  end process;

  output_process : process
  begin
    while count < 22 loop
      wait for 10 ns;
      strip(count, "data " & hex(data) & " | level " & bits(level) & mark(rst, "(RESET)"));
    end loop;
    wait;
  end process;
end behaviour;

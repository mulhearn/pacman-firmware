library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- adc_cmp:  ADC comparator with hysteresis
--
-- Parameters (registers, register_map.vhd):
--   THRESH  (12 bits)  threshold
--   SWING   (12 bits)  hysteresis:  LEVEL_O goes high when the data reaches THRESH + SWING, low when it falls to
--                      THRESH - SWING (both clipped to the 12-bit range), and holds in between
--
-- LEVEL_O lags the data by one clock.

entity adc_cmp is
  port (
    CLK_I       : in  std_logic;
    RST_I       : in  std_logic;
    DATA_I      : in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    THRESH_I    : in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    SWING_I     : in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    LEVEL_O     : out std_logic
  );
end adc_cmp;

architecture rtl of adc_cmp is
  signal level : std_logic := '0';
begin

  process(CLK_I, RST_I)
    variable thresh, swing, lo, hi : unsigned(ADC_DATA_WIDTH-1 downto 0);
  begin
    if (RST_I = '1') then
      level <= '0';
    elsif rising_edge(CLK_I) then
      thresh := unsigned(THRESH_I);
      swing  := unsigned(SWING_I);
      if thresh < swing then
        lo := (others => '0');
      else
        lo := thresh - swing;
      end if;
      if (not thresh) < swing then
        hi := (others => '1');
      else
        hi := thresh + swing;
      end if;
      if unsigned(DATA_I) >= hi then
        level <= '1';
      elsif unsigned(DATA_I) <= lo then
        level <= '0';
      end if;
    end if;
  end process;

  LEVEL_O <= level;

end rtl;

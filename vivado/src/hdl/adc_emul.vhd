library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- adc_emul: ADC emulator, a simple parmeterized ramp for testing the ADC module.
--
-- Parameters (registers, register_map.vhd):
--   MIN     (12 bits)  ramp start, and its minimum
--   MAX     (12 bits)  ramp maximum
--   STEP    (13 bits)  change per step, signed:  STEP > 0 ramps up, past MAX back to MIN;
--                      STEP < 0 ramps down, below MIN back to MAX;  STEP = 0 holds
--   PERIOD  (16 bits)  one step every PERIOD clocks;  PERIOD = 0 holds
--
-- While ENABLE_I is low the ramp sits at MIN; it starts when ENABLE_I goes high (adc_unit: when
-- ADC_MUX selects the emulator).

entity adc_emul is
  port (
    CLK_I       : in  std_logic;
    RST_I       : in  std_logic;
    ENABLE_I    : in  std_logic;
    MIN_I       : in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    MAX_I       : in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    STEP_I      : in  std_logic_vector(ADC_DATA_WIDTH downto 0);
    PERIOD_I    : in  std_logic_vector(15 downto 0);
    DATA_O      : out std_logic_vector(ADC_DATA_WIDTH-1 downto 0)
  );
end adc_emul;

architecture rtl of adc_emul is
  signal ramp : unsigned(ADC_DATA_WIDTH-1 downto 0) := (others => '0');
  signal cnt  : unsigned(15 downto 0) := (others => '0');
begin

  process(CLK_I, RST_I)
    variable step         : signed(ADC_DATA_WIDTH downto 0);
    variable lo, hi       : unsigned(ADC_DATA_WIDTH-1 downto 0);
    variable nxt          : signed(ADC_DATA_WIDTH+1 downto 0);
  begin
    if (RST_I = '1') then
      ramp <= (others => '0');
      cnt  <= (others => '0');
    elsif rising_edge(CLK_I) then
      step  := signed(STEP_I);
      lo    := unsigned(MIN_I);
      hi    := unsigned(MAX_I);
      if ENABLE_I = '0' then
        ramp <= lo;
        cnt  <= (others => '0');
      elsif unsigned(PERIOD_I) = 0 then
        cnt  <= (others => '0');
      elsif cnt < unsigned(PERIOD_I) - 1 then
        cnt  <= cnt + 1;
      else
        cnt  <= (others => '0');
        nxt  := signed(resize(ramp, ADC_DATA_WIDTH+2)) + resize(step, ADC_DATA_WIDTH+2);
        if step >= 0 and nxt > signed(resize(hi, ADC_DATA_WIDTH+2)) then
          ramp <= lo;
        elsif step < 0 and nxt < signed(resize(lo, ADC_DATA_WIDTH+2)) then
          ramp <= hi;
        else
          ramp <= unsigned(nxt(ADC_DATA_WIDTH-1 downto 0));
        end if;
      end if;
    end if;
  end process;

  DATA_O <= std_logic_vector(ramp);

end rtl;

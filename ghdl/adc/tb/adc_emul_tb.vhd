----------------------------------------------------------------------------------------------------
-- adc_emul_tb:  ADC emulator test bench
--
-- The ramp sits at MIN while ENABLE is low, then moves by STEP every PERIOD clocks:  past MAX
-- back to MIN (STEP > 0), below MIN back to MAX (STEP < 0).
--
-- Shows one line per clock: en = ENABLE | data (hex).
--
-- Scenario: MIN 0x010, MAX 0x01C, STEP 3, PERIOD 2;  ENABLE from 50 ns  -- (alternatives in
-- comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity adc_emul_tb is
end adc_emul_tb;

architecture behaviour of adc_emul_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal enable : std_logic;
  signal lo     : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal hi     : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal step   : std_logic_vector(ADC_DATA_WIDTH downto 0);
  signal period : std_logic_vector(15 downto 0);
  signal data   : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
begin
  -- the emulator configuration (alternatives in comments):
  lo     <= x"010";
  hi     <= x"01C";
  step   <= '0' & x"003";                                       -- up by 3
  --step   <= '1' & x"FFD";                                     -- down by 3
  --step   <= '0' & x"000";                                     -- holds
  period <= x"0002";                                            -- every 2 clocks
  --period <= x"0001";                                          -- every clock
  --period <= x"0000";                                          -- holds

  uut: entity work.adc_emul port map (
    CLK_I    => clk,
    RST_I    => rst,
    ENABLE_I => enable,
    MIN_I    => lo,
    MAX_I    => hi,
    STEP_I   => step,
    PERIOD_I => period,
    DATA_O   => data
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

  enable_process : process
  begin
    enable <= '0';
    wait for 50 ns;
    enable <= '1';
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 30 loop
      wait for 10 ns;
      strip(count, "en " & bits(enable) & " | data " & hex(data) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

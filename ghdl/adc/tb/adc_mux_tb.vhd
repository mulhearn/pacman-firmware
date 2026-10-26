----------------------------------------------------------------------------------------------------
-- adc_mux_tb:  ADC mux test bench
--
-- SELECT 0:  the ADC pins (data and overflow);  SELECT 1:  the emulator, overflow 0.
--
-- Shows one line per clock: sel | pins data, dof | emulator data | out data, dof.
--
-- Scenario: pins 0xABC with overflow, emulator 0x123;  SELECT 1 from 30 ns to 60 ns
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity adc_mux_tb is
end adc_mux_tb;

architecture behaviour of adc_mux_tb is
  signal count    : integer := 0;
  signal clk      : std_logic;
  signal sel      : std_logic;
  signal adc_data : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal adc_dof  : std_logic;
  signal emul     : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal data     : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal dof      : std_logic;
begin
  adc_data <= x"ABC";
  adc_dof  <= '1';
  emul     <= x"123";

  uut: entity work.adc_mux port map (
    SELECT_I    => sel,
    ADC_DATA_I  => adc_data,
    ADC_DOF_I   => adc_dof,
    EMUL_DATA_I => emul,
    DATA_O      => data,
    DOF_O       => dof
  );

  clk_process : process
  begin
    count <= count + 1;
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  select_process : process
  begin
    sel <= '0';
    wait for 30 ns;
    sel <= '1';
    wait for 30 ns;
    sel <= '0';
    wait;
  end process;

  output_process : process
  begin
    while count < 9 loop
      wait for 10 ns;
      strip(count, "sel " & bits(sel) & " | pins " & hex(adc_data) & " " & bits(adc_dof) & " | emul " & hex(emul) &
                   " | out " & hex(data) & " " & bits(dof));
    end loop;
    wait;
  end process;
end behaviour;

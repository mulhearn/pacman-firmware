library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- adc_mux: the ADC data used in the ADC unit (LOOK, comparator): the ADC pins (SELECT_I = 0), or
-- the emulator (SELECT_I = 1, overflow 0).

entity adc_mux is
  port (
    SELECT_I    : in  std_logic;
    ADC_DATA_I  : in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    ADC_DOF_I   : in  std_logic;
    EMUL_DATA_I : in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    DATA_O      : out std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    DOF_O       : out std_logic
  );
end adc_mux;

architecture rtl of adc_mux is
begin
  DATA_O <= EMUL_DATA_I when SELECT_I = '1' else ADC_DATA_I;
  DOF_O  <= '0'         when SELECT_I = '1' else ADC_DOF_I;
end rtl;

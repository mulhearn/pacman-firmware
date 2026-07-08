library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

entity timer is
  port (
    CLK_I      : in  std_logic;
    RST_I      : in  std_logic;
    CONFIG_I   : in  std_logic_vector(31 downto 0);
    STROBE_O   : out std_logic
  );
end entity timer;

architecture rtl of timer is
  signal cfg_period : unsigned(31 downto 0);
  signal count      : unsigned(31 downto 0) := (others => '0');
begin

  cfg_period <= unsigned(CONFIG_I);

  process(CLK_I)
  begin
    if RST_I = '1' then
      count    <= (others => '0');
      STROBE_O <= '0';
    elsif rising_edge(CLK_I) then
      STROBE_O <= '0';
      if cfg_period = 0 then
        STROBE_O <= '0';
      elsif count >= cfg_period - 1 then
        count    <= (others => '0');
        STROBE_O <= '1';
      else
        count <= count + 1;
      end if;
    end if;
  end process;

end architecture rtl;

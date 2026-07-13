library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

entity timestamp is

  port (
    --clock and active high reset:
    CLK_I       : in  std_logic;
    RST_I       : in  std_logic;
    SYNC_I      : in  std_logic;

    --clock enable strobe:
    ENABLE_I    : in  std_logic;

    -- current count
    TIMESTAMP_O     : out std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0)
  );
end;

architecture behavioral of timestamp is
  signal count_reg : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);

begin

  -- Register inputs
  process(CLK_I, RST_I)
    variable count : unsigned(C_TIMESTAMP_WIDTH-1 downto 0);
  begin
    if RST_I = '1' then
      count  := to_unsigned(1, C_TIMESTAMP_WIDTH);
      count_reg <= std_logic_vector(to_unsigned(1, C_TIMESTAMP_WIDTH));
      TIMESTAMP_O <= (others => '0');
    elsif rising_edge(CLK_I) then
      if (SYNC_I='1') then
        count := to_unsigned(0, C_TIMESTAMP_WIDTH);
      end if;
      if ENABLE_I='1' then
        count := count + 1;
        count_reg <= std_logic_vector(count);
        TIMESTAMP_O <= count_reg;
      end if;
    end if;
  end process;

end behavioral;



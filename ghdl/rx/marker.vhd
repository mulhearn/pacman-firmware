library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- marker:  add a timestamp to rx buffer to mark the occurance of something

entity marker is
  port (
    CLK_I         : in  std_logic;
    RST_I         : in  std_logic;
    EN_I          : in  std_logic;
    TIMESTAMP_O   : out  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    VALID_O       : out std_logic;
    READY_I       : in  std_logic;
    TIMESTAMP_I   : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    MARKER_I      : in  std_logic;
    DEBUG_O       : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
  );
end;

architecture behavioral of marker is
  signal clk        : std_logic;
  signal rst        : std_logic;

  signal valid      : std_logic;
  signal ready      : std_logic;


begin
  clk <= CLK_I;
  rst <= RST_I;

  VALID_O <= valid;
  ready <= READY_I;

  process(clk,rst)
  begin
    if (rst='1') then
      valid <= '0';
      TIMESTAMP_O <= (others => '0');
    elsif (rising_edge(clk)) then
      if ((valid='1') and (ready='1')) then
        TIMESTAMP_O <= (others => '0');
        valid <= '0';
      end if;
      if ((EN_I='1') and (MARKER_I='1')) then
        if ((valid='0') or ((valid='1') and (ready='1'))) then
          valid <= '1';
          TIMESTAMP_O <= TIMESTAMP_I;
        end if;
      end if;
    end if;
  end process;

end;

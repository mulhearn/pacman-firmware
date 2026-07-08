library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

entity counter is

  port (
    --clock and active high reset:
    CLK_I       : in  std_logic;
    RST_I       : in  std_logic;

    -- increment the count
    INCREMENT_I : in  std_logic;
    -- count runs only while run is high
    RUN_I       : in  std_logic;
    -- count resets to zero on clear
    CLEAR_I     : in  std_logic;
    -- current count
    COUNT_O     : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
  );
end;

architecture behavioral of counter is

  signal run_reg        : std_logic;
  signal increment_rega : std_logic;
  signal increment_regb : std_logic;
  signal clear_reg      : std_logic;

  signal count_next_edge   : unsigned(C_COUNT_BITS-1 downto 0);
  signal count_rega_edge   : unsigned(C_COUNT_BITS-1 downto 0);
  signal count_regb_edge   : unsigned(C_COUNT_BITS-1 downto 0);

  signal count_next_int    : unsigned(C_COUNT_BITS-1 downto 0);
  signal count_rega_int    : unsigned(C_COUNT_BITS-1 downto 0);
  signal count_regb_int    : unsigned(C_COUNT_BITS-1 downto 0);

begin

  -- Register inputs
  process(CLK_I, RST_I)
  begin
    if RST_I = '1' then
      run_reg        <= '0';
      increment_rega <= '1';
      increment_regb <= '1';
      clear_reg      <= '0';
    elsif rising_edge(CLK_I) then
      run_reg        <= RUN_I;
      increment_rega <= INCREMENT_I;
      increment_regb <= increment_rega;
      clear_reg      <= CLEAR_I;
    end if;
  end process;

  -- Combinatorial next value: edge count (rising-edge detect, as before)
  process(run_reg, increment_rega, increment_regb, clear_reg, count_rega_edge)
  begin
    count_next_edge <= count_rega_edge;
    if clear_reg = '1' then
      count_next_edge <= (others => '0');
    elsif run_reg = '1' and increment_rega = '1' and increment_regb = '0' and count_rega_edge < C_COUNT_MAX then
      count_next_edge <= count_rega_edge + 1;
    end if;
  end process;

  -- Combinatorial next value: integral (level count, one tick per clock while high)
  process(run_reg, increment_rega, increment_regb, clear_reg, count_rega_int, count_rega_edge)
  begin
    count_next_int <= count_rega_int;

    if clear_reg = '1' then
      count_next_int <= (others => '0');
    elsif run_reg = '1' and increment_rega = '1' and
      ((increment_regb = '0') or (count_rega_edge > 0)) and
      count_rega_int < C_COUNT_MAX then
      count_next_int <= count_rega_int + 1;
    end if;
  end process;

  -- Two-stage registered outputs (edge count)
  process(CLK_I, RST_I)
  begin
    if RST_I = '1' then
      count_rega_edge <= (others => '0');
      count_regb_edge <= (others => '0');
    elsif rising_edge(CLK_I) then
      count_rega_edge <= count_next_edge;
      count_regb_edge <= count_rega_edge;
    end if;
  end process;

  -- Two-stage registered outputs (integral)
  process(CLK_I, RST_I)
  begin
    if RST_I = '1' then
      count_rega_int <= (others => '0');
      count_regb_int <= (others => '0');
    elsif rising_edge(CLK_I) then
      count_rega_int <= count_next_int;
      count_regb_int <= count_rega_int;
    end if;
  end process;

  -- Output: edge count in low half, integral in high half
  COUNT_O <= std_logic_vector(count_regb_int) & std_logic_vector(count_regb_edge);

end behavioral;



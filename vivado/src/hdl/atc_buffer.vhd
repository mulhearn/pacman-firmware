library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity atc_buffer is
  generic (
    C_NCHAN : natural := C_NUM_TILE
  );
  port (
    -- clock and active-high reset:
    CLK_I      : in  std_logic;
    RST_I      : in  std_logic;

    -- uart period strobe (one sys_clk cycle wide):
    UART_I     : in  std_logic;

    -- signal input (active-high):
    SIG_I      : in  std_logic_vector(C_NCHAN-1 downto 0);

    -- configuration:
    -- [7:0]        cfg_phase  -- delay in sys_clk cycles after UART_I (0=next cycle)
    -- [8+C_NCHAN-1:8] cfg_invert -- per-channel invert, 1=active-low
    CONFIG_I   : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

    -- signal output (active-high or low based on cfg_invert),
    -- aligned to UART_I + cfg_phase, held until next alignment point:
    SIG_O      : out std_logic_vector(C_NCHAN-1 downto 0)
  );
end entity atc_buffer;

architecture rtl of atc_buffer is
  signal cfg_phase  : unsigned(7 downto 0);
  signal cfg_invert : std_logic_vector(C_NCHAN-1 downto 0);
  signal phase_cnt  : unsigned(7 downto 0) := (others => '0');
  signal clk_en     : std_logic;
  signal sig_next   : std_logic_vector(C_NCHAN-1 downto 0);
  signal locked     : std_logic := '0';
begin

  cfg_phase  <= unsigned(CONFIG_I(7 downto 0));
  cfg_invert <= CONFIG_I(8+C_NCHAN-1 downto 8);

  -- phase counter: resets on uart_i, counts up to cfg_phase
  process(CLK_I)
  begin
    if RST_I = '1' then
      locked <= '0';
      phase_cnt <= (others => '0');
    elsif rising_edge(CLK_I) then
      if UART_I = '1' then
        locked <= '1';
        phase_cnt <= (others => '0');
      else
        phase_cnt <= phase_cnt + 1;
      end if;
    end if;
  end process;

  -- clk_en fires one cycle after phase_cnt reaches cfg_phase
  clk_en <= '1' when locked='1' and phase_cnt = cfg_phase else '0';

  -- combinational inversion
  gen_inv: for i in 0 to C_NCHAN-1 generate
    sig_next(i) <= not SIG_I(i) when cfg_invert(i) = '1' else SIG_I(i);
  end generate;

  -- registered output, gated by clk_en
  process(CLK_I)
  begin
    if RST_I = '1' then
      SIG_O <= (others => '0');
    elsif rising_edge(CLK_I) and  clk_en = '1' then
      SIG_O <= sig_next;
    end if;
  end process;

end architecture rtl;

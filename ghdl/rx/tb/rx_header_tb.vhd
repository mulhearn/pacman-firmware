----------------------------------------------------------------------------------------------------
-- rx_header_tb:  RX header test bench
--
-- The header for each RX channel, one clock after its select:  UART channels 0-39 get channel id
-- i+1, the PACMAN id and the word type;  selects 40-43 give the extra headers A-D;  beyond, zero.
--
-- Shows one line per clock: sel | h = channel id, PACMAN id, word type ("upper:" if the upper 32
-- bits are set).
--
-- Scenario: PACMAN id 15, word type 44;  selects 1, 2, 3, ... one per clock  -- (alternatives in
-- comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity rx_header_tb is
end rx_header_tb;

architecture behaviour of rx_header_tb is
  signal count   : integer := 0;
  signal clk     : std_logic;
  signal rst     : std_logic;
  signal rst_z   : std_logic;
  signal header  : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0);
  signal cselect : std_logic_vector(C_SELECT_WIDTH-1 downto 0) := (others => '0');
  signal wtype   : std_logic_vector(C_BYTE-1 downto 0);
  signal chan    : uart_small_array_t;
  signal header_a : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal header_b : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal header_c : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal header_d : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal pacman   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  -- the header configuration (alternatives in comments):
  header_a <= x"00481553";                                      -- extra header A (select 40)
  header_b <= x"00531553";                                      -- extra header B (select 41)
  header_c <= x"0000CCCC";                                      -- extra header C (select 42)
  header_d <= x"0000DDDD";                                      -- extra header D (select 43)
  pacman   <= x"00000015";                                      -- PACMAN id 15
  --pacman   <= x"0000002A";                                    -- PACMAN id 2A

  uut: entity work.rx_header port map (
    CLK_I      => clk,
    RST_I      => rst,
    SEL_I      => cselect,
    WTYPE_I    => wtype,
    HEADER_A_I => header_a,
    HEADER_B_I => header_b,
    HEADER_C_I => header_c,
    HEADER_D_I => header_d,
    PACMAN_I   => pacman,
    CHAN_I     => chan,
    HEADER_O   => header
  );

  chan_process : process
  begin
    for i in 0 to 39 loop
      chan(i) <= std_logic_vector(to_unsigned(i + 1, 16));
    end loop;
    wait;
  end process;

  cselect_process : process
  begin
    wait for 2 ns;
    cselect <= std_logic_vector(to_unsigned(count, cselect'length));
    if count = 40 then note("selects 28-2B (40-43):  the extra headers A-D, as configured;  then nothing"); end if;
    wait for 8 ns;
  end process;

  -- word type:  44 for the UART channels (decided elsewhere in the RX unit), 0 otherwise
  wtype_process : process
  begin
    wait for 1 ns;
    if (rst='1') or (rst_z='1') or (to_integer(unsigned(cselect)) >= 40) then
      wtype <= x"00";
    else
      wtype <= x"44";
    end if;
    wait for 9 ns;
  end process;

  clk_process : process
  begin
    rst_z <= rst;
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

  -- header = [31:16] channel | [15:8] PACMAN id | [7:0] word type (upper 32 bits shown only if set)
  output_process : process
  begin
    while count < 50 loop
      wait for 10 ns;
      strip(count, "sel " & hex("00" & cselect) & " | h " & hex(header(31 downto 16)) & " " & hex(header(15 downto 8))
            & " " & hex(header(7 downto 0)) & mark(header(63) or header(62), "upper: " & hex(header(63 downto 32)))
            & mark(rst, "(RESET)"));
    end loop;
    wait;
  end process;
end behaviour;

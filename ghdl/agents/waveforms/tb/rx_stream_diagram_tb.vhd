-- Diagram testbench (make waveforms):  rx_buffer streaming three words and the trailer, for the firmware
-- description (rx_stream.pdf).  UART channels 0, 1 and 3 hold data;  CONFIG 00030000:  at most 3 words per
-- packet, no timeout, so the third word closes the packet.  The mux inputs follow the channel select one
-- clock later, as in rx_unit:  header (channel id | PACMAN id 01 | word type D), timestamp, data.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

entity rx_stream_diagram_tb is
end rx_stream_diagram_tb;

architecture behaviour of rx_stream_diagram_tb is
  signal clk    : std_logic := '1';
  signal rst    : std_logic := '1';
  signal tdata  : std_logic_vector(63 downto 0);
  signal tvalid : std_logic;
  signal tlast  : std_logic;
  signal sel    : std_logic_vector(C_SELECT_WIDTH-1 downto 0);
  signal header : std_logic_vector(63 downto 0) := (others => '0');
  signal frag_a : std_logic_vector(63 downto 0) := (others => '0');
  signal frag_b : std_logic_vector(63 downto 0) := (others => '0');
  signal valid  : std_logic_vector(C_RX_NUM_CHAN-1 downto 0) := (others => '0');
  signal ready  : std_logic_vector(C_RX_NUM_CHAN-1 downto 0);
  signal status : std_logic_vector(31 downto 0);
  signal state  : std_logic_vector(2 downto 0);
  signal turn   : std_logic_vector(5 downto 0);
  signal frag   : std_logic_vector(1 downto 0);
  signal valid0, valid1, valid3, ready0, ready1, ready3 : std_logic;
begin
  state  <= status(2 downto 0);
  turn   <= status(13 downto 8);
  frag   <= status(15 downto 14);
  valid0 <= valid(0);
  valid1 <= valid(1);
  valid3 <= valid(3);
  ready0 <= ready(0);
  ready1 <= ready(1);
  ready3 <= ready(3);

  uut: entity work.rx_buffer port map (
    CLK_I         => clk,
    RST_I         => rst,
    M_AXIS_TDATA  => tdata,
    M_AXIS_TVALID => tvalid,
    M_AXIS_TREADY => '1',
    M_AXIS_TKEEP  => open,
    M_AXIS_TLAST  => tlast,
    STATUS_O      => open,
    CONFIG_I      => x"00030000",
    CHAN_SELECT_O => sel,
    HEADER_I      => header,
    FRAG_A_I      => frag_a,
    FRAG_B_I      => frag_b,
    VALID_I       => valid,
    READY_O       => ready,
    EOP_HEADER_I  => x"0000004C",
    DEBUG_O       => status
  );

  clk <= not clk after 5 ns;
  rst <= '0' after 20 ns;

  -- the registered muxes of rx_unit:  header, timestamp and data of the selected channel, one clock later
  process(clk)
    variable c : integer;
  begin
    if rising_edge(clk) then
      c := to_integer(unsigned(sel));
      header <= std_logic_vector(to_unsigned(c + 1, 48)) & x"0144";
      frag_a <= std_logic_vector(to_unsigned(16#1000# + 16 * c, 64));
      frag_b <= x"00000000DA7A00" & std_logic_vector(to_unsigned(c, 8));
    end if;
  end process;

  -- channels 0, 1 and 3 receive a word at 100 ns;  each valid clears on its ready (as in rx_chan)
  process(clk)
  begin
    if rising_edge(clk) then
      if now > 95 ns and now < 105 ns then
        valid(0) <= '1';
        valid(1) <= '1';
        valid(3) <= '1';
      else
        valid <= valid and not ready;
      end if;
    end if;
  end process;
end behaviour;

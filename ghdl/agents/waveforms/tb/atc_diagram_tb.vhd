-- Diagram testbench (make waveforms):  atc_unit, for the firmware description (atc_timer.pdf, atc_poke.pdf,
-- atc_lemo.pdf).  Default UART and BAUD periods (10 clocks).
--   0-400 ns:   the strobes, UCLK and the timestamp, as after reset
--   POKE C:     destination H on tiles 0-3 and marker 0 (SYNC:  the timestamp restarts), 25 clocks;
--               CONFIG_H phase 3;  the poke's own mask selects tiles 0 and 1
--   LEMO A:     destination G on all tiles, 12 clocks;  a 15 ns glitch (too short to be seen as an edge),
--               then two rising edges, each one pulse
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;

entity atc_diagram_tb is
end atc_diagram_tb;

architecture behaviour of atc_diagram_tb is
  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';
  signal waddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wupdate : std_logic := '0';
  signal lemo_a  : std_logic := '0';
  signal ts      : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal ts16    : std_logic_vector(15 downto 0);
  signal marker  : std_logic_vector(C_NUM_MARKER-1 downto 0);
  signal uclk    : std_logic;
  signal baud    : std_logic;
  signal g, h    : std_logic_vector(C_NUM_TILE-1 downto 0);
begin
  ts16 <= ts(15 downto 0);

  uut: entity work.atc_unit port map (
    ACLK                => clk,
    RST_I               => rst,
    S_REGBUS_RB_RADDR   => (others => '0'),
    S_REGBUS_RB_RDATA   => open,
    S_REGBUS_RB_RUPDATE => '0',
    S_REGBUS_RB_RACK    => open,
    S_REGBUS_RB_WUPDATE => wupdate,
    S_REGBUS_RB_WADDR   => waddr,
    S_REGBUS_RB_WDATA   => wdata,
    S_REGBUS_RB_WACK    => open,
    LEMO_A_I            => lemo_a,
    LEMO_B_I            => '0',
    BAUD_O              => baud,
    TIMESTAMP_O         => ts,
    RX_MARKER_O         => marker,
    UCLK_O              => uclk,
    G_O                 => g,
    H_O                 => h
  );

  clk <= not clk after 5 ns;
  rst <= '0' after 20 ns;

  process
    procedure wr(reg : integer; d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
      waddr   <= std_logic_vector(to_unsigned(C_SCOPE_ATC * 16#1000# + reg, 16));
      wdata   <= d;
      wupdate <= '1';
      wait until rising_edge(clk);
      wait for 1 ns;
      wupdate <= '0';
      waddr   <= (others => '0');
      wdata   <= (others => '0');
    end procedure;
  begin
    wait for 500 ns;
    wr(C_ADDR_ATC_CONFIG_H,      x"00000003");
    wr(C_ADDR_ATC_DST_POKE_C,    x"001903C6");    -- 25 clocks | tiles 0-3 | marker 0 | H
    wr(C_ADDR_ATC_CONFIG_G,      x"00000000");
    wr(C_ADDR_ATC_DST_LEMO_A,    x"000CFFC1");    -- 12 clocks | all tiles | G
    wait for 200 ns;
    wr(C_ADDR_ATC_POKE_C,        x"00000003");    -- this poke:  tiles 0 and 1
    wait;
  end process;

  process
  begin
    wait for 1503 ns;
    lemo_a <= '1';
    wait for 15 ns;
    lemo_a <= '0';             -- a 15 ns glitch:  one synchronized sample, not an edge
    wait for 15 ns;
    lemo_a <= '1';             -- a rising edge
    wait for 70 ns;
    lemo_a <= '0';
    wait for 150 ns;
    lemo_a <= '1';             -- another rising edge
    wait for 60 ns;
    lemo_a <= '0';
    wait;
  end process;
end behaviour;

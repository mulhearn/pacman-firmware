library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
use work.common.all;

entity regbus_cdc_tb is
end regbus_cdc_tb;

architecture behaviour of regbus_cdc_tb is
  component regbus_cdc is
    port (
      S_CLK_I              : in  std_logic;
      S_RST_I              : in  std_logic;
      S_REGBUS_RB_RUPDATE  : in  std_logic;
      S_REGBUS_RB_RDATA    : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RACK     : out std_logic;
      S_REGBUS_RB_WUPDATE  : in  std_logic;
      S_REGBUS_RB_WACK     : out std_logic;

      P_CLK_I              : in  std_logic;
      P_RST_I              : in  std_logic;
      P_REGBUS_RB_RUPDATE  : out std_logic;
      P_REGBUS_RB_RDATA    : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      P_REGBUS_RB_RACK     : in  std_logic;
      P_REGBUS_RB_WUPDATE  : out std_logic;
      P_REGBUS_RB_WACK     : in  std_logic
    );
  end component;

  signal count    : integer := 0;

  signal s_clk     : std_logic;
  signal s_rst     : std_logic;
  signal s_rupdate : std_logic := '0';
  signal s_rack    : std_logic;
  signal s_wupdate : std_logic := '0';
  signal s_wack    : std_logic;

  signal p_clk     : std_logic;
  signal p_rst     : std_logic;
  signal p_rupdate : std_logic;
  signal p_rack    : std_logic := '0';
  signal p_wupdate : std_logic;
  signal p_wack    : std_logic := '0';

begin
  uut: regbus_cdc port map (
      S_CLK_I              => s_clk,
      S_RST_I              => s_rst,
      S_REGBUS_RB_RUPDATE  => s_rupdate,
      S_REGBUS_RB_RACK     => s_rack,
      S_REGBUS_RB_WUPDATE  => s_wupdate,
      S_REGBUS_RB_WACK     => s_wack,

      P_CLK_I               => p_clk,
      P_RST_I               => p_rst,
      P_REGBUS_RB_RUPDATE   => p_rupdate,
      P_REGBUS_RB_RDATA     => (others => '0'),
      P_REGBUS_RB_RACK     => p_rack,
      P_REGBUS_RB_WUPDATE  => p_wupdate,
      P_REGBUS_RB_WACK     => p_wack
      );

  s_rst_process : process
  begin
    s_rst <= '1';
    wait for 12 ns;
    s_rst <= '0';
    wait;
  end process;

  p_rst_process : process
  begin
    p_rst <= '1';
    wait for 19 ns;  -- deliberately offset from s_rst release
    p_rst <= '0';
    wait;
  end process;

  -- axi_clk-like: 100 MHz
  s_clk_process : process
  begin
    count <= count + 1;
    s_clk <= '1';
    wait for 5 ns;
    s_clk <= '0';
    wait for 5 ns;
  end process;

  -- sys_clk-like: 62.5 MHz
  p_clk_process : process
  begin
    p_clk <= '1';
    wait for 8 ns;
    p_clk <= '0';
    wait for 8 ns;
  end process;

  s_stimulus_process : process
  begin
    s_rupdate <= '0';
    s_wupdate <= '0';
    wait for 50 ns;

    s_rupdate <= '1';
    wait for 10 ns;
    s_rupdate <= '0';
    wait for 40 ns;

    s_wupdate <= '1';
    wait for 10 ns;
    s_wupdate <= '0';
    wait for 40 ns;

    -- back-to-back read updates, to see two toggles queue up
    s_rupdate <= '1';
    wait for 10 ns;
    s_rupdate <= '0';
    wait for 20 ns;
    s_rupdate <= '1';
    wait for 10 ns;
    s_rupdate <= '0';
    wait;
  end process;

  -- drive acks from the P side, independent of P_REGBUS_RB_RUPDATE/WUPDATE
  -- (this is a dumb primitive -- it doesn't gate on request, so acks are
  -- free-running stimulus here, not a real target model)
  p_stimulus_process : process
  begin
    p_rack <= '0';
    p_wack <= '0';
    wait for 120 ns;

    p_rack <= '1';
    wait for 16 ns;
    p_rack <= '0';
    wait for 80 ns;

    p_wack <= '1';
    wait for 16 ns;
    p_wack <= '0';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    if (count < 30) then
      wait for 8 ns;
    else
      wait;
    end if;

    write (l, String'("c: "));
    write (l, count, left, 4);
    write (l, String'(" S: c:"));
    write (l, s_clk);
    write (l, String'(" ru:"));
    write (l, s_rupdate);
    write (l, String'(" rk:"));
    write (l, s_rack);
    write (l, String'(" wu:"));
    write (l, s_wupdate);
    write (l, String'(" wk:"));
    write (l, s_wack);
    write (l, String'(" P: c: "));
    write (l, p_clk);
    write (l, String'(" ru:"));
    write (l, p_rupdate);
    write (l, String'(" rk:"));
    write (l, p_rack);
    write (l, String'(" wu:"));
    write (l, p_wupdate);
    write (l, String'(" wk:"));
    write (l, p_wack);
    writeline(output, l);
  end process;

end behaviour;

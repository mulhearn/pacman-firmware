library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
use work.common.all;

entity regbus_hub_tb is
end regbus_hub_tb;

architecture behaviour of regbus_hub_tb is
  component regbus_hub is
    port (
      S_CLK_I               : in  std_logic;
      S_RST_I                : in  std_logic;
      P_CLK_I                : in  std_logic;
      P_RST_I                : in  std_logic;

      S_REGBUS_RB_RUPDATE  : in   std_logic;
      S_REGBUS_RB_RADDR    : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_RDATA    : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RACK     : out  std_logic;
      S_REGBUS_RB_WUPDATE  : in   std_logic;
      S_REGBUS_RB_WADDR    : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_WDATA    : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WACK     : out  std_logic;

      PA_REGBUS_RB_RUPDATE : out  std_logic;
      PA_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PA_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PA_REGBUS_RB_RACK    : in   std_logic;
      PA_REGBUS_RB_WUPDATE : out  std_logic;
      PA_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PA_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PA_REGBUS_RB_WACK    : in   std_logic;

      PB_REGBUS_RB_RUPDATE : out  std_logic;
      PB_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PB_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PB_REGBUS_RB_RACK    : in   std_logic;
      PB_REGBUS_RB_WUPDATE : out  std_logic;
      PB_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PB_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PB_REGBUS_RB_WACK    : in   std_logic;

      PL_REGBUS_RB_RUPDATE : out  std_logic;
      PL_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PL_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PL_REGBUS_RB_RACK    : in   std_logic;
      PL_REGBUS_RB_WUPDATE : out  std_logic;
      PL_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PL_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PL_REGBUS_RB_WACK    : in   std_logic;

      PM_REGBUS_RB_RUPDATE : out  std_logic;
      PM_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PM_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PM_REGBUS_RB_RACK    : in   std_logic;
      PM_REGBUS_RB_WUPDATE : out  std_logic;
      PM_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PM_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PM_REGBUS_RB_WACK    : in   std_logic;

      PN_REGBUS_RB_RUPDATE : out  std_logic;
      PN_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PN_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PN_REGBUS_RB_RACK    : in   std_logic;
      PN_REGBUS_RB_WUPDATE : out  std_logic;
      PN_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      PN_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PN_REGBUS_RB_WACK    : in   std_logic;

      DEBUG                 : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
    );
  end component;

  signal count    : integer := 0;

  signal s_clk     : std_logic;
  signal s_rst     : std_logic;
  signal p_clk     : std_logic;
  signal p_rst     : std_logic;

  -- secondary interface (drive requests here):
  signal s_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal s_rupdate : std_logic := '0';
  signal s_rdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal s_rack    : std_logic;
  signal s_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal s_wupdate : std_logic := '0';
  signal s_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal s_wack    : std_logic;

  -- PA/PB: unused in this TB, tied inert (no ack, no data)
  signal pa_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pa_rupdate : std_logic;
  signal pa_wupdate : std_logic;
  signal pa_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pa_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  signal pb_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pb_rupdate : std_logic;
  signal pb_wupdate : std_logic;
  signal pb_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pb_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  -- PL: the one primary under test
  signal pl_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pl_rupdate : std_logic;
  signal pl_rdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal pl_rack    : std_logic := '0';
  signal pl_wupdate : std_logic;
  signal pl_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pl_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal pl_wack    : std_logic := '0';

  -- PM/PN: unused in this TB, tied inert
  signal pm_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pm_rupdate : std_logic;
  signal pm_wupdate : std_logic;
  signal pm_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pm_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  signal pn_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pn_rupdate : std_logic;
  signal pn_wupdate : std_logic;
  signal pn_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal pn_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  signal pl_resp_toggle : std_logic := '0';


begin
  uut: regbus_hub port map (
      S_CLK_I               => s_clk,
      S_RST_I                => s_rst,
      P_CLK_I                => p_clk,
      P_RST_I                => p_rst,

      S_REGBUS_RB_RUPDATE  => s_rupdate,
      S_REGBUS_RB_RADDR    => s_raddr,
      S_REGBUS_RB_RDATA    => s_rdata,
      S_REGBUS_RB_RACK     => s_rack,
      S_REGBUS_RB_WUPDATE  => s_wupdate,
      S_REGBUS_RB_WADDR    => s_waddr,
      S_REGBUS_RB_WDATA    => s_wdata,
      S_REGBUS_RB_WACK     => s_wack,

      PA_REGBUS_RB_RUPDATE => pa_rupdate,
      PA_REGBUS_RB_RADDR   => pa_raddr,
      PA_REGBUS_RB_RDATA   => x"00000000",
      PA_REGBUS_RB_RACK    => '0',
      PA_REGBUS_RB_WUPDATE => pa_wupdate,
      PA_REGBUS_RB_WADDR   => pa_waddr,
      PA_REGBUS_RB_WDATA   => pa_wdata,
      PA_REGBUS_RB_WACK    => '0',

      PB_REGBUS_RB_RUPDATE => pb_rupdate,
      PB_REGBUS_RB_RADDR   => pb_raddr,
      PB_REGBUS_RB_RDATA   => x"00000000",
      PB_REGBUS_RB_RACK    => '0',
      PB_REGBUS_RB_WUPDATE => pb_wupdate,
      PB_REGBUS_RB_WADDR   => pb_waddr,
      PB_REGBUS_RB_WDATA   => pb_wdata,
      PB_REGBUS_RB_WACK    => '0',

      PL_REGBUS_RB_RUPDATE => pl_rupdate,
      PL_REGBUS_RB_RADDR   => pl_raddr,
      PL_REGBUS_RB_RDATA   => pl_rdata,
      PL_REGBUS_RB_RACK    => pl_rack,
      PL_REGBUS_RB_WUPDATE => pl_wupdate,
      PL_REGBUS_RB_WADDR   => pl_waddr,
      PL_REGBUS_RB_WDATA   => pl_wdata,
      PL_REGBUS_RB_WACK    => pl_wack,

      PM_REGBUS_RB_RUPDATE => pm_rupdate,
      PM_REGBUS_RB_RADDR   => pm_raddr,
      PM_REGBUS_RB_RDATA   => x"00000000",
      PM_REGBUS_RB_RACK    => '0',
      PM_REGBUS_RB_WUPDATE => pm_wupdate,
      PM_REGBUS_RB_WADDR   => pm_waddr,
      PM_REGBUS_RB_WDATA   => pm_wdata,
      PM_REGBUS_RB_WACK    => '0',

      PN_REGBUS_RB_RUPDATE => pn_rupdate,
      PN_REGBUS_RB_RADDR   => pn_raddr,
      PN_REGBUS_RB_RDATA   => x"00000000",
      PN_REGBUS_RB_RACK    => '0',
      PN_REGBUS_RB_WUPDATE => pn_wupdate,
      PN_REGBUS_RB_WADDR   => pn_waddr,
      PN_REGBUS_RB_WDATA   => pn_wdata,
      PN_REGBUS_RB_WACK    => '0',

      DEBUG => open
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

  -- drive requests from the secondary side, addressed/data'd for PL:
  s_stimulus_process : process
  begin
    s_raddr   <= x"0000";
    s_rupdate <= '0';
    s_waddr   <= x"0000";
    s_wdata   <= x"00000000";
    s_wupdate <= '0';
    wait for 30 ns;

    s_raddr   <= x"FF00";
    s_rupdate <= '1';
    wait for 10 ns;
    s_rupdate <= '0';

    s_waddr   <= x"F100";
    s_wdata   <= x"11111111";
    s_wupdate <= '1';
    wait for 10 ns;
    s_wupdate <= '0';

    wait for 120 ns;

    s_raddr   <= x"FF04";
    s_rupdate <= '1';
    wait for 10 ns;
    s_rupdate <= '0';

    s_waddr   <= x"F104";
    s_wdata   <= x"22222222";
    s_wupdate <= '1';
    wait for 10 ns;
    s_wupdate <= '0';

    wait;


  end process;

  pl_response_process : process(p_clk)
  begin
    if rising_edge(p_clk) then
      pl_rack <= '0';
      pl_wack <= '0';
      if (pl_rupdate = '1') then
        if (pl_resp_toggle = '0') then
          pl_rdata <= x"AAAAAAAA";
        else
          pl_rdata <= x"BBBBBBBB";
        end if;
        pl_resp_toggle <= not pl_resp_toggle;
        pl_rack        <= '1';
      end if;
      if (pl_wupdate = '1') then
        pl_wack <= '1';
      end if;
    end if;
  end process;



  output_process : process(s_clk)
    variable l : line;
  begin
    if falling_edge(s_clk) then
      write (l, String'("c: "));
      write (l, count, left, 4);
      write (l, String'(" S: ra:0x"));
      hwrite(l, s_raddr);
      write (l, String'(" ru:"));
      write (l, s_rupdate);
      write (l, String'(" rd:0x"));
      hwrite(l, s_rdata);
      write (l, String'(" rk:"));
      write (l, s_rack);
      write (l, String'(" wa:0x"));
      hwrite(l, s_waddr);
      write (l, String'(" wd:0x"));
      hwrite(l, s_wdata);
      write (l, String'(" wu:"));
      write (l, s_wupdate);
      write (l, String'(" wk:"));
      write (l, s_wack);
      write (l, String'(" | PL: ra:0x"));
      hwrite(l, pl_raddr);
      write (l, String'(" ru:"));
      write (l, pl_rupdate);
      write (l, String'(" rd:0x"));
      hwrite(l, pl_rdata);
      write (l, String'(" rk:"));
      write (l, pl_rack);
      write (l, String'(" wa:0x"));
      hwrite(l, pl_waddr);
      write (l, String'(" wd:0x"));
      hwrite(l, pl_wdata);
      write (l, String'(" wu:"));
      write (l, pl_wupdate);
      write (l, String'(" wk:"));
      write (l, pl_wack);
      writeline(output, l);
    end if;
  end process;

end behaviour;

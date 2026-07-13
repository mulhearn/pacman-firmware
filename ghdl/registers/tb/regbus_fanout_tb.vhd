library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
use work.common.all;

--  Defines a testbench (without any ports)
entity regbus_fanout_tb is
end regbus_fanout_tb;

architecture behaviour of regbus_fanout_tb is
  constant N_PRIMARY : integer := 3;

  component regbus_fanout is
    generic (
      N_PRIMARY : integer := 3
    );
    port (
      -- Secondary REGBUS:
      S_REGBUS_RB_RUPDATE  : in   std_logic;
      S_REGBUS_RB_RADDR    : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_RDATA    : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RACK     : out  std_logic;
      S_REGBUS_RB_WUPDATE  : in   std_logic;
      S_REGBUS_RB_WADDR    : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_WDATA    : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WACK     : out  std_logic;
      -- Primary REGBUS arrays:
      P_REGBUS_RB_RUPDATE  : out  std_logic_vector(0 to N_PRIMARY-1);
      P_REGBUS_RB_RADDR    : out  regbus_addr_array_t(0 to N_PRIMARY-1);
      P_REGBUS_RB_RDATA    : in   regbus_data_array_t(0 to N_PRIMARY-1);
      P_REGBUS_RB_RACK     : in   std_logic_vector(0 to N_PRIMARY-1);
      P_REGBUS_RB_WUPDATE  : out  std_logic_vector(0 to N_PRIMARY-1);
      P_REGBUS_RB_WADDR    : out  regbus_addr_array_t(0 to N_PRIMARY-1);
      P_REGBUS_RB_WDATA    : out  regbus_data_array_t(0 to N_PRIMARY-1);
      P_REGBUS_RB_WACK     : in   std_logic_vector(0 to N_PRIMARY-1)
    );
  end component;

  signal show_write : std_logic := '1';
  signal show_read  : std_logic := '0';

  signal count    : integer := 0;
  signal aclk     : std_logic;
  signal aresetn  : std_logic;  -- NOTE: mapped to RST_I -- see polarity flag at bottom

  -- secondary interface:
  signal s_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal s_rupdate : std_logic := '0';
  signal s_rdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal s_rack    : std_logic := '0';
  signal s_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal s_wupdate : std_logic := '0';
  signal s_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal s_wack    : std_logic := '0';

  -- primary interfaces, arrayed (index 0=A, 1=B, 2=C, matching old lettering):
  signal p_raddr   : regbus_addr_array_t(0 to N_PRIMARY-1) := (others => (others => '0'));
  signal p_rupdate : std_logic_vector(0 to N_PRIMARY-1) := (others => '0');
  signal p_rdata   : regbus_data_array_t(0 to N_PRIMARY-1);
  signal p_rack    : std_logic_vector(0 to N_PRIMARY-1) := (others => '0');
  signal p_waddr   : regbus_addr_array_t(0 to N_PRIMARY-1) := (others => (others => '0'));
  signal p_wupdate : std_logic_vector(0 to N_PRIMARY-1) := (others => '0');
  signal p_wdata   : regbus_data_array_t(0 to N_PRIMARY-1) := (others => (others => '0'));
  signal p_wack    : std_logic_vector(0 to N_PRIMARY-1) := (others => '0');

begin
  uut: regbus_fanout
    generic map (
      N_PRIMARY => N_PRIMARY
    )
    port map (
      S_REGBUS_RB_RUPDATE  => s_rupdate,
      S_REGBUS_RB_RADDR    => s_raddr,
      S_REGBUS_RB_RDATA    => s_rdata,
      S_REGBUS_RB_RACK     => s_rack,
      S_REGBUS_RB_WUPDATE  => s_wupdate,
      S_REGBUS_RB_WADDR    => s_waddr,
      S_REGBUS_RB_WDATA    => s_wdata,
      S_REGBUS_RB_WACK     => s_wack,

      P_REGBUS_RB_RUPDATE  => p_rupdate,
      P_REGBUS_RB_RADDR    => p_raddr,
      P_REGBUS_RB_RDATA    => p_rdata,
      P_REGBUS_RB_RACK     => p_rack,
      P_REGBUS_RB_WUPDATE  => p_wupdate,
      P_REGBUS_RB_WADDR    => p_waddr,
      P_REGBUS_RB_WDATA    => p_wdata,
      P_REGBUS_RB_WACK     => p_wack
      );

  aresetn_process : process
  begin
    aresetn <= '1';
    wait for 10 ns;
    aresetn <= '0';
    wait;
  end process;

  aclk_process : process
  begin
    count <= count + 1;
    aclk <= '1';
    wait for 5 ns;
    aclk <= '0';
    wait for 5 ns;
  end process;

  secondary_output_process : process
  begin
    s_waddr   <= x"0000";
    s_wdata   <= x"00000000";
    s_wupdate <= '0';
    s_raddr   <= x"0000";
    s_rupdate <= '0';
    wait for 20 ns;
    s_waddr   <= x"F100";
    s_wdata   <= x"AAAAAAAA";
    s_wupdate <= '1';
    s_raddr   <= x"FF00";
    s_rupdate <= '1';
    wait for 10 ns;
    s_waddr   <= x"F104";
    s_wdata   <= x"BBBBBBBB";
    s_wupdate <= '1';
    s_raddr   <= x"FF04";
    s_rupdate <= '1';
    wait for 10 ns;
    s_waddr   <= x"F108";
    s_wdata   <= x"CCCCCCCC";
    s_wupdate <= '1';
    s_raddr   <= x"FF08";
    s_rupdate <= '1';
    wait for 10 ns;
    s_waddr   <= x"F10C";
    s_wdata   <= x"11111111";
    s_wupdate <= '1';
    s_raddr   <= x"FF0C";
    s_rupdate <= '1';
    wait for 10 ns;
    s_waddr   <= x"F110";
    s_wdata   <= x"22222222";
    s_wupdate <= '1';
    s_raddr   <= x"FF10";
    s_rupdate <= '1';
    wait for 10 ns;
    s_waddr   <= x"0000";
    s_wdata   <= x"00000000";
    s_wupdate <= '0';
    s_raddr   <= x"0000";
    s_rupdate <= '0';
    wait;
  end process;

  primary_output_process : process
  begin
    p_rdata(0) <= x"00000000"; p_rack(0) <= '0'; p_wack(0) <= '0';
    p_rdata(1) <= x"00000000"; p_rack(1) <= '0'; p_wack(1) <= '0';
    p_rdata(2) <= x"00000000"; p_rack(2) <= '0'; p_wack(2) <= '0';
    wait for 20 ns;
    p_rdata(0) <= x"00000000"; p_rack(0) <= '0'; p_wack(0) <= '0';
    p_rdata(1) <= x"FEEDDADA"; p_rack(1) <= '1'; p_wack(1) <= '0';
    p_rdata(2) <= x"00000000"; p_rack(2) <= '0'; p_wack(2) <= '1';
    wait for 10 ns;
    p_rdata(0) <= x"CAFEF00D"; p_rack(0) <= '1'; p_wack(0) <= '0';
    p_rdata(1) <= x"00000000"; p_rack(1) <= '0'; p_wack(1) <= '1';
    p_rdata(2) <= x"00000000"; p_rack(2) <= '0'; p_wack(2) <= '0';
    wait for 10 ns;
    p_rdata(0) <= x"11111111"; p_rack(0) <= '1'; p_wack(0) <= '1';
    p_rdata(1) <= x"00000000"; p_rack(1) <= '0'; p_wack(1) <= '0';
    p_rdata(2) <= x"22222222"; p_rack(2) <= '0'; p_wack(2) <= '0';
    -- priority should go to :
    wait for 10 ns;
    p_rdata(0) <= x"11111111"; p_rack(0) <= '0'; p_wack(0) <= '1';
    p_rdata(1) <= x"00000000"; p_rack(1) <= '0'; p_wack(1) <= '0';
    p_rdata(2) <= x"22222222"; p_rack(2) <= '1'; p_wack(2) <= '0';
    wait for 10 ns;
    p_rdata(0) <= x"11111111"; p_rack(0) <= '1'; p_wack(0) <= '0';
    p_rdata(1) <= x"00000000"; p_rack(1) <= '0'; p_wack(1) <= '0';
    p_rdata(2) <= x"22222222"; p_rack(2) <= '1'; p_wack(2) <= '1';
    wait for 10 ns;
    p_rdata(0) <= x"00000000"; p_rack(0) <= '0'; p_wack(0) <= '0';
    p_rdata(1) <= x"00000000"; p_rack(1) <= '0'; p_wack(1) <= '0';
    p_rdata(2) <= x"00000000"; p_rack(2) <= '0'; p_wack(2) <= '0';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    if (count < 10) then
      wait for 10 ns;
    else
      wait;
    end if;

    write (l, String'("c: "));
    write (l, count, left, 4);
    write (l, String'("aclk: "));
    write (l, aclk);
    if (show_read='1') then
       write (l, String'(" || ra: 0x"));
       hwrite(l, s_raddr);
       write (l, String'(" ru:"));
       write (l, s_rupdate);
       write (l, String'(" rd: 0x"));
       hwrite(l, s_rdata);
       write (l, String'(" rk:"));
       write (l, s_rack);
       write (l, String'(" ark:"));
       write (l, p_rack(0));
       write (l, String'(" brk:"));
       write (l, p_rack(1));
       write (l, String'(" crk:"));
       write (l, p_rack(2));
       write (l, String'(" ra: 0x"));
       hwrite(l, p_rdata(0));
       write (l, String'(" rb: 0x"));
       hwrite(l, p_rdata(1));
       write (l, String'(" rc: 0x"));
       hwrite(l, p_rdata(2));
       write (l, String'(" || ra: 0x"));
       hwrite(l, p_raddr(0));
       write (l, String'(" rb: 0x"));
       hwrite(l, p_raddr(1));
       write (l, String'(" rc: 0x"));
       hwrite(l, p_raddr(2));
    end if;
    if (show_write='1') then
       write (l, String'(" || wa: 0x"));
       hwrite (l,s_waddr);
       write (l, String'(" wu:"));
       write (l, s_wupdate);
       write (l, String'(" wd: 0x"));
       hwrite (l,s_wdata);
       write (l, String'(" wk:"));
       write (l, s_wack);
       write (l, String'(" awk:"));
       write (l, p_wack(0));
       write (l, String'(" bwk:"));
       write (l, p_wack(1));
       write (l, String'(" cwk:"));
       write (l, p_wack(2));
       write (l, String'(" wa: 0x"));
       hwrite(l, p_wdata(0));
       write (l, String'(" wb: 0x"));
       hwrite(l, p_wdata(1));
       write (l, String'(" wc: 0x"));
       hwrite(l, p_wdata(2));
       write (l, String'(" || wa: 0x"));
       hwrite(l, p_waddr(0));
       write (l, String'(" wb: 0x"));
       hwrite(l, p_waddr(1));
       write (l, String'(" wc: 0x"));
       hwrite(l, p_waddr(2));
    end if;
    if (aresetn = '1') then
      write (l, String'(" (RESET)"));
    end if;
    writeline(output, l);
  end process;

end behaviour;

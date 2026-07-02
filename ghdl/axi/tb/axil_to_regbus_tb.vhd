library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08


--  Defines a testbench (without any ports)
entity axil_to_regbus_tb is
  generic (
    constant C_ADDR_WIDTH : integer := 16;
    constant C_DATA_WIDTH : integer := 32
  );
end axil_to_regbus_tb;

architecture behaviour of axil_to_regbus_tb is
  component axil_to_regbus is
    generic (
      constant C_ADDR_WIDTH : integer := C_ADDR_WIDTH;
      constant C_DATA_WIDTH : integer := C_DATA_WIDTH;
      constant C_TIMEOUT_CYCLES : integer := 2
      );
    port (
      S_AXI_ACLK         : in std_logic;
      S_AXI_ARESETN      : in std_logic;
      S_AXI_ARADDR       : in std_logic_vector(C_ADDR_WIDTH-1 downto 0);
      S_AXI_ARPROT       : in std_logic_vector(2 downto 0) := (others => '0');
      S_AXI_ARVALID      : in std_logic;
      S_AXI_ARREADY      : out std_logic;
      S_AXI_RDATA        : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
      S_AXI_RRESP        : out std_logic_vector(1 downto 0);
      S_AXI_RVALID       : out std_logic;
      S_AXI_RREADY       : in std_logic;
      S_AXI_AWADDR       : in std_logic_vector(C_ADDR_WIDTH-1 downto 0);
      S_AXI_AWPROT       : in std_logic_vector(2 downto 0) := (others => '0');
      S_AXI_AWVALID      : in std_logic;
      S_AXI_AWREADY      : out std_logic;
      S_AXI_WDATA        : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
      S_AXI_WSTRB        : in std_logic_vector((C_DATA_WIDTH/8)-1 downto 0) := (others => '0');
      S_AXI_WVALID       : in std_logic;
      S_AXI_WREADY       : out std_logic;
      S_AXI_BRESP        : out std_logic_vector(1 downto 0);
      S_AXI_BVALID       : out std_logic;
      S_AXI_BREADY       : in std_logic;
      P_REGBUS_RB_RUPDATE      : out std_logic;
      P_REGBUS_RB_RADDR	       : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
      P_REGBUS_RB_RDATA	       : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
      P_REGBUS_RB_RACK         : in std_logic;
      P_REGBUS_RB_WUPDATE      : out std_logic;
      P_REGBUS_RB_WADDR	       : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
      P_REGBUS_RB_WDATA	       : out  std_logic_vector(C_DATA_WIDTH-1 downto 0);
      P_REGBUS_RB_WACK         : in std_logic
    );
  end component;
  signal count    : integer := 0;
  signal aclk     : std_logic;
  signal aresetn  : std_logic;
  -- read signals:
  signal araddr   : std_logic_vector(C_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal arvalid  : std_logic := '0';
  signal arready  : std_logic;
  signal rdata    : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal rvalid   : std_logic := '0';
  signal rready   : std_logic;
  -- write signals:
  signal awaddr   : std_logic_vector(C_ADDR_WIDTH-1 downto 0)  := (others => '0');
  signal awvalid  : std_logic := '0';
  signal awready  : std_logic;
  signal wdata    : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal wvalid   : std_logic:= '0';
  signal wready   : std_logic;
  signal bvalid   : std_logic;
  signal bready   : std_logic:='0';
  signal rupdate  : std_logic;
  signal wupdate  : std_logic;

  signal rack     : std_logic;
  signal wack     : std_logic;

  signal rb_rdata  : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal rb_wdata  : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');

begin
  uut: axil_to_regbus port map (
    S_AXI_ACLK     => aclk,
    S_AXI_ARESETN  => aresetn,
    S_AXI_ARADDR   => araddr,
    S_AXI_ARVALID  => arvalid,
    S_AXI_ARREADY  => arready,
    S_AXI_RDATA    => rdata,
    S_AXI_RVALID   => rvalid,
    S_AXI_RREADY   => rready,
    S_AXI_AWADDR   => awaddr,
    S_AXI_AWVALID  => awvalid,
    S_AXI_AWREADY  => awready,
    S_AXI_WDATA    => wdata,
    S_AXI_WVALID   => wvalid,
    S_AXI_WREADY   => wready,
    S_AXI_BVALID   => bvalid,
    S_AXI_BREADY   => bready,
    P_REGBUS_RB_RDATA    => rb_rdata,
    P_REGBUS_RB_RUPDATE  => rupdate,
    P_REGBUS_RB_RACK     => rack,
    P_REGBUS_RB_WDATA    => rb_wdata,
    P_REGBUS_RB_WUPDATE  => wupdate,
    P_REGBUS_RB_WACK     => wack
  );

  aresetn_process : process
  begin
    aresetn <= '0';
    wait for 20 ns;
    aresetn <= '1';
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

  read_process : process
  begin
    wait for 1 ns;
    rb_rdata <= x"00000000";
    araddr   <= x"0000";
    arvalid  <= '0';
    rack     <= '0';
    rready   <= '0';
    wait for 10 ns;
    wait for 10 ns;
    araddr   <= x"0000";
    arvalid  <= '1';
    rready   <= '1';
    wait for 10 ns;
    wait for 10 ns;
    rb_rdata <= x"AAAAAAAA";
    rack     <= '1';
    araddr   <= x"0004";
    wait for 10 ns;
    rb_rdata <= x"00000000";
    rack     <= '0';
    wait for 10 ns;
    wait for 10 ns;
    wait for 10 ns;
    rb_rdata <= x"BBBBBBBB";
    rack     <= '1';
    araddr   <= x"0008";
    wait for 10 ns;
    rb_rdata <= x"00000000";
    rack     <= '0';
    wait for 10 ns;
    wait for 10 ns;
    wait for 10 ns;
    araddr   <= x"0000";
    arvalid  <= '0';
    wait for 20 ns;
    rb_rdata <= x"CCCCCCCC";
    rack     <= '1';
    wait for 10 ns;
    rb_rdata <= x"00000000";
    rack     <= '0';
    wait for 10 ns;
    rb_rdata <= x"00000000";
    araddr   <= x"0000";
    arvalid  <= '0';
    rack     <= '0';
    rready   <= '0';
    wait;
  end process;

  write_process : process
  begin
    wait for 1 ns;
    awaddr <= x"0000";
    awvalid  <= '0';
    wdata  <= x"00000000";
    wvalid  <= '0';
    wack     <= '0';
    wait for 20 ns;
    bready <= '1';
    awaddr <= x"0000";
    awvalid  <= '1';
    wdata  <= x"11111111";
    wvalid  <= '1';
    wait for 20 ns;
    awaddr <= x"0004";
    wdata  <= x"22222222";
    wack     <= '1';
    wait for 10 ns;
    wack     <= '0';
    wait for 10 ns;
    wait for 10 ns;
    wait for 10 ns;
    awaddr <= x"0008";
    wdata  <= x"33333333";
    wack     <= '0';
    wait for 10 ns;
    wack     <= '1';
    wait for 10 ns;
    wack     <= '0';
    wait for 10 ns;
    bready   <= '0';
    wait for 10 ns;
    wait for 10 ns;
    awaddr <= x"0000";
    awvalid  <= '0';
    wdata  <= x"00000000";
    wvalid  <= '0';
    wait for 10 ns;
    --wack    <= '1';
    wait for 10 ns;
    wack     <= '0';
    wait for 10 ns;
    bready   <= '1';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    if (count < 18) then
      wait for 10 ns;
    else
      wait;
    end if;

    write (l, String'("c: "));
    write (l, count, left, 4);
    --write (l, String'(" aclk: "));
    --write (l, aclk);
    write (l, String'(" |ar: 0x"));
    hwrite (l, araddr);
    write (l, String'(" vr:"));
    write (l, arvalid);
    write (l, arready);
    write (l, String'(" r: 0x"));
    hwrite (l, rdata);
    write (l, String'(" vr: "));
    write (l, rvalid);
    write (l, rready);
    write (l, String'(" ua: "));
    write (l, rupdate);
    write (l, rack);
    write (l, String'(" |aw: 0x"));
    hwrite (l, awaddr);
    write (l, String'(" vr:"));
    write (l, awvalid);
    write (l, awready);
    write (l, String'(" w vr: "));
    write (l, wvalid);
    write (l, wready);
    write (l, String'(" ua: "));
    write (l, wupdate);
    write (l, wack);
    write (l, String'(" d: 0x"));
    hwrite (l, rb_wdata);
    write (l, String'(" b vr: "));
    write (l, bvalid);
    write (l, bready);
    if (aresetn = '0') then
      write (l, String'(" (RST)"));
    end if;
    writeline(output, l);
  end process;

end behaviour;


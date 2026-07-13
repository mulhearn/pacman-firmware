library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity regbus_hub is
  port (
    -- Secondary REGBUS domain clock/reset (also PA/PB/PC domain)
    S_CLK_I               : in  std_logic;
    S_RST_I               : in  std_logic;

    -- Primary PL/PM/PN domain clock/reset
    P_CLK_I                : in  std_logic;
    P_RST_I                : in  std_logic;

    -- Secondary REGBUS (S_CLK_I domain):
    S_REGBUS_RB_RUPDATE  : in   std_logic;
    S_REGBUS_RB_RADDR    : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_RDATA    : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RACK     : out  std_logic;

    S_REGBUS_RB_WUPDATE  : in   std_logic;
    S_REGBUS_RB_WADDR    : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_WDATA    : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_WACK     : out  std_logic;

    -- Primary A REGBUS (S_CLK_I domain)
    PA_REGBUS_RB_RUPDATE : out  std_logic;
    PA_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PA_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PA_REGBUS_RB_RACK    : in   std_logic;

    PA_REGBUS_RB_WUPDATE : out  std_logic;
    PA_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PA_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PA_REGBUS_RB_WACK    : in   std_logic;

    -- Primary B REGBUS (S_CLK_I domain)
    PB_REGBUS_RB_RUPDATE : out  std_logic;
    PB_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PB_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PB_REGBUS_RB_RACK    : in   std_logic;

    PB_REGBUS_RB_WUPDATE : out  std_logic;
    PB_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PB_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PB_REGBUS_RB_WACK    : in   std_logic;

    -- Primary C REGBUS (S_CLK_I domain) -- future addition
    --PC_REGBUS_RB_RUPDATE : out  std_logic;
    --PC_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    --PC_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    --PC_REGBUS_RB_RACK    : in   std_logic;

    --PC_REGBUS_RB_WUPDATE : out  std_logic;
    --PC_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    --PC_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    --PC_REGBUS_RB_WACK    : in   std_logic;

    -- Primary L REGBUS (P_CLK_I domain)
    PL_REGBUS_RB_RUPDATE : out  std_logic;
    PL_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PL_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PL_REGBUS_RB_RACK    : in   std_logic;

    PL_REGBUS_RB_WUPDATE : out  std_logic;
    PL_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PL_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PL_REGBUS_RB_WACK    : in   std_logic;

    -- Primary M REGBUS (P_CLK_I domain)
    PM_REGBUS_RB_RUPDATE : out  std_logic;
    PM_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PM_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PM_REGBUS_RB_RACK    : in   std_logic;

    PM_REGBUS_RB_WUPDATE : out  std_logic;
    PM_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PM_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PM_REGBUS_RB_WACK    : in   std_logic;

    -- Primary N REGBUS (P_CLK_I domain)
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
end;

architecture behavioral of regbus_hub is

  component regbus_fanout is
    generic (
      N_PRIMARY     : integer  := 3
    );
    port (
      S_REGBUS_RB_RUPDATE  : in   std_logic;
      S_REGBUS_RB_RADDR	 : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_RDATA	 : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RACK     : out  std_logic;

      S_REGBUS_RB_WUPDATE  : in   std_logic;
      S_REGBUS_RB_WADDR	 : in   std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_WDATA	 : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WACK     : out  std_logic;

      P_REGBUS_RB_RUPDATE  : out  std_logic_vector(0 to N_PRIMARY-1);
      P_REGBUS_RB_RADDR	 : out  regbus_addr_array_t(0 to N_PRIMARY-1);
      P_REGBUS_RB_RDATA	 : in   regbus_data_array_t(0 to N_PRIMARY-1);
      P_REGBUS_RB_RACK     : in   std_logic_vector(0 to N_PRIMARY-1);

      P_REGBUS_RB_WUPDATE  : out  std_logic_vector(0 to N_PRIMARY-1);
      P_REGBUS_RB_WADDR	 : out  regbus_addr_array_t(0 to N_PRIMARY-1);
      P_REGBUS_RB_WDATA	 : out  regbus_data_array_t(0 to N_PRIMARY-1);
      P_REGBUS_RB_WACK     : in   std_logic_vector(0 to N_PRIMARY-1)
      );
  end component;

  component regbus_cdc is
    port (
      S_CLK_I               : in  std_logic;
      S_RST_I                : in  std_logic;
      S_REGBUS_RB_RUPDATE   : in  std_logic;
      S_REGBUS_RB_RACK      : out std_logic;
      S_REGBUS_RB_RDATA     : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WUPDATE   : in  std_logic;
      S_REGBUS_RB_WACK      : out std_logic;

      P_CLK_I                : in  std_logic;
      P_RST_I                : in  std_logic;
      P_REGBUS_RB_RUPDATE   : out std_logic;
      P_REGBUS_RB_RACK      : in  std_logic;
      P_REGBUS_RB_RDATA     : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      P_REGBUS_RB_WUPDATE   : out std_logic;
      P_REGBUS_RB_WACK      : in  std_logic
      );
  end component;

  ---------------------------------------------------------------------------
  -- Top-level fanout: secondary -> PA, PB, CDC branch
  ---------------------------------------------------------------------------
  constant N_TOP : integer := 3;  -- future PC -> 4

  signal top_rupdate : std_logic_vector(0 to N_TOP-1);
  signal top_raddr   : regbus_addr_array_t(0 to N_TOP-1);
  signal top_rdata   : regbus_data_array_t(0 to N_TOP-1);
  signal top_rack    : std_logic_vector(0 to N_TOP-1);
  signal top_wupdate : std_logic_vector(0 to N_TOP-1);
  signal top_waddr   : regbus_addr_array_t(0 to N_TOP-1);
  signal top_wdata   : regbus_data_array_t(0 to N_TOP-1);
  signal top_wack    : std_logic_vector(0 to N_TOP-1);

  ---------------------------------------------------------------------------
  -- P_CLK_I-domain fanout: CDC branch -> PL, PM, PN
  ---------------------------------------------------------------------------
  constant N_PLMN : integer := 3;

  signal plmn_rupdate : std_logic_vector(0 to N_PLMN-1);
  signal plmn_raddr   : regbus_addr_array_t(0 to N_PLMN-1);
  signal plmn_rdata   : regbus_data_array_t(0 to N_PLMN-1);
  signal plmn_rack    : std_logic_vector(0 to N_PLMN-1);
  signal plmn_wupdate : std_logic_vector(0 to N_PLMN-1);
  signal plmn_waddr   : regbus_addr_array_t(0 to N_PLMN-1);
  signal plmn_wdata   : regbus_data_array_t(0 to N_PLMN-1);
  signal plmn_wack    : std_logic_vector(0 to N_PLMN-1);

  -- fanout_plmn's "secondary side" -- this is the P_CLK_I-domain aggregation
  -- point that the CDC talks to. RADDR/WADDR/WDATA are combinational
  -- passthroughs (quasi-static, held for the round trip); RUPDATE/RACK/
  -- WUPDATE/WACK/RDATA are handled inside regbus_cdc (RDATA is masked to
  -- zero there until this branch's own ack has landed -- see regbus_cdc).
  signal p_rupdate : std_logic;
  signal p_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal p_rdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal p_rack    : std_logic;
  signal p_wupdate : std_logic;
  signal p_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal p_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal p_wack    : std_logic;

begin

  ---------------------------------------------------------------------------
  -- Top fanout: secondary -> {PA, PB, CDC branch}
  ---------------------------------------------------------------------------
  u_fanout_top : regbus_fanout
    generic map (
      N_PRIMARY => N_TOP
      )
    port map (
      S_REGBUS_RB_RUPDATE  => S_REGBUS_RB_RUPDATE,
      S_REGBUS_RB_RADDR    => S_REGBUS_RB_RADDR,
      S_REGBUS_RB_RDATA    => S_REGBUS_RB_RDATA,
      S_REGBUS_RB_RACK     => S_REGBUS_RB_RACK,

      S_REGBUS_RB_WUPDATE  => S_REGBUS_RB_WUPDATE,
      S_REGBUS_RB_WADDR    => S_REGBUS_RB_WADDR,
      S_REGBUS_RB_WDATA    => S_REGBUS_RB_WDATA,
      S_REGBUS_RB_WACK     => S_REGBUS_RB_WACK,

      P_REGBUS_RB_RUPDATE  => top_rupdate,
      P_REGBUS_RB_RADDR    => top_raddr,
      P_REGBUS_RB_RDATA    => top_rdata,
      P_REGBUS_RB_RACK     => top_rack,

      P_REGBUS_RB_WUPDATE  => top_wupdate,
      P_REGBUS_RB_WADDR    => top_waddr,
      P_REGBUS_RB_WDATA    => top_wdata,
      P_REGBUS_RB_WACK     => top_wack
      );

  -- PA <-> index 0
  PA_REGBUS_RB_RUPDATE <= top_rupdate(0);
  PA_REGBUS_RB_RADDR   <= top_raddr(0);
  top_rdata(0)          <= PA_REGBUS_RB_RDATA;
  top_rack(0)           <= PA_REGBUS_RB_RACK;
  PA_REGBUS_RB_WUPDATE <= top_wupdate(0);
  PA_REGBUS_RB_WADDR   <= top_waddr(0);
  PA_REGBUS_RB_WDATA   <= top_wdata(0);
  top_wack(0)           <= PA_REGBUS_RB_WACK;

  -- PB <-> index 1
  PB_REGBUS_RB_RUPDATE <= top_rupdate(1);
  PB_REGBUS_RB_RADDR   <= top_raddr(1);
  top_rdata(1)          <= PB_REGBUS_RB_RDATA;
  top_rack(1)           <= PB_REGBUS_RB_RACK;
  PB_REGBUS_RB_WUPDATE <= top_wupdate(1);
  PB_REGBUS_RB_WADDR   <= top_waddr(1);
  PB_REGBUS_RB_WDATA   <= top_wdata(1);
  top_wack(1)           <= PB_REGBUS_RB_WACK;

  -- future: PC <-> index 3, bump N_TOP to 4 above and uncomment the port
  --PC_REGBUS_RB_RUPDATE <= top_rupdate(3);
  --PC_REGBUS_RB_RADDR   <= top_raddr(3);
  --top_rdata(3)          <= PC_REGBUS_RB_RDATA;
  --top_rack(3)           <= PC_REGBUS_RB_RACK;
  --PC_REGBUS_RB_WUPDATE <= top_wupdate(3);
  --PC_REGBUS_RB_WADDR   <= top_waddr(3);
  --PC_REGBUS_RB_WDATA   <= top_wdata(3);
  --top_wack(3)           <= PC_REGBUS_RB_WACK;

  ---------------------------------------------------------------------------
  -- CDC: S_CLK_I -> P_CLK_I strobes, index 2. RDATA masking (zero until this
  -- branch's own ack lands) happens inside regbus_cdc. ADDR/WDATA cross as
  -- plain combinational wires below, held stable by the req/ack handshake.
  ---------------------------------------------------------------------------
  u_cdc : regbus_cdc
    port map (
      S_CLK_I               => S_CLK_I,
      S_RST_I                => S_RST_I,
      S_REGBUS_RB_RUPDATE   => top_rupdate(2),
      S_REGBUS_RB_RACK      => top_rack(2),
      S_REGBUS_RB_RDATA     => top_rdata(2),
      S_REGBUS_RB_WUPDATE   => top_wupdate(2),
      S_REGBUS_RB_WACK      => top_wack(2),

      P_CLK_I                => P_CLK_I,
      P_RST_I                => P_RST_I,
      P_REGBUS_RB_RUPDATE   => p_rupdate,
      P_REGBUS_RB_RACK      => p_rack,
      P_REGBUS_RB_RDATA     => p_rdata,
      P_REGBUS_RB_WUPDATE   => p_wupdate,
      P_REGBUS_RB_WACK      => p_wack
      );

  -- ADDR/WDATA passthrough into the P_CLK_I domain (quasi-static, no register)
  p_raddr <= top_raddr(2);
  p_waddr <= top_waddr(2);
  p_wdata <= top_wdata(2);

  ---------------------------------------------------------------------------
  -- PL/PM/PN fanout (P_CLK_I domain, behind the CDC)
  ---------------------------------------------------------------------------
  u_fanout_plmn : regbus_fanout
    generic map (
      N_PRIMARY => N_PLMN
      )
    port map (
      S_REGBUS_RB_RUPDATE  => p_rupdate,
      S_REGBUS_RB_RADDR    => p_raddr,
      S_REGBUS_RB_RDATA    => p_rdata,
      S_REGBUS_RB_RACK     => p_rack,

      S_REGBUS_RB_WUPDATE  => p_wupdate,
      S_REGBUS_RB_WADDR    => p_waddr,
      S_REGBUS_RB_WDATA    => p_wdata,
      S_REGBUS_RB_WACK     => p_wack,

      P_REGBUS_RB_RUPDATE  => plmn_rupdate,
      P_REGBUS_RB_RADDR    => plmn_raddr,
      P_REGBUS_RB_RDATA    => plmn_rdata,
      P_REGBUS_RB_RACK     => plmn_rack,

      P_REGBUS_RB_WUPDATE  => plmn_wupdate,
      P_REGBUS_RB_WADDR    => plmn_waddr,
      P_REGBUS_RB_WDATA    => plmn_wdata,
      P_REGBUS_RB_WACK     => plmn_wack
      );

  -- PL <-> index 0
  PL_REGBUS_RB_RUPDATE <= plmn_rupdate(0);
  PL_REGBUS_RB_RADDR   <= plmn_raddr(0);
  plmn_rdata(0)         <= PL_REGBUS_RB_RDATA;
  plmn_rack(0)          <= PL_REGBUS_RB_RACK;
  PL_REGBUS_RB_WUPDATE <= plmn_wupdate(0);
  PL_REGBUS_RB_WADDR   <= plmn_waddr(0);
  PL_REGBUS_RB_WDATA   <= plmn_wdata(0);
  plmn_wack(0)          <= PL_REGBUS_RB_WACK;

  -- PM <-> index 1
  PM_REGBUS_RB_RUPDATE <= plmn_rupdate(1);
  PM_REGBUS_RB_RADDR   <= plmn_raddr(1);
  plmn_rdata(1)         <= PM_REGBUS_RB_RDATA;
  plmn_rack(1)          <= PM_REGBUS_RB_RACK;
  PM_REGBUS_RB_WUPDATE <= plmn_wupdate(1);
  PM_REGBUS_RB_WADDR   <= plmn_waddr(1);
  PM_REGBUS_RB_WDATA   <= plmn_wdata(1);
  plmn_wack(1)          <= PM_REGBUS_RB_WACK;

  -- PN <-> index 2
  PN_REGBUS_RB_RUPDATE <= plmn_rupdate(2);
  PN_REGBUS_RB_RADDR   <= plmn_raddr(2);
  plmn_rdata(2)         <= PN_REGBUS_RB_RDATA;
  plmn_rack(2)          <= PN_REGBUS_RB_RACK;
  PN_REGBUS_RB_WUPDATE <= plmn_wupdate(2);
  PN_REGBUS_RB_WADDR   <= plmn_waddr(2);
  PN_REGBUS_RB_WDATA   <= plmn_wdata(2);
  plmn_wack(2)          <= PN_REGBUS_RB_WACK;

  DEBUG <= (others => '0');

end;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity regbus_hub is
  port (
    -- Secondary REGBUS domain clock/reset (also the secondary-domain ports)
    S_CLK_I               : in  std_logic;
    S_RST_I               : in  std_logic;

    -- Primary domain clock/reset (the primary-domain ports)
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

    -- Primary B REGBUS (S_CLK_I domain):  not in use;  to add it, uncomment here and below, N_SEC 3
    --PB_REGBUS_RB_RUPDATE : out  std_logic;
    --PB_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    --PB_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    --PB_REGBUS_RB_RACK    : in   std_logic;

    --PB_REGBUS_RB_WUPDATE : out  std_logic;
    --PB_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    --PB_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    --PB_REGBUS_RB_WACK    : in   std_logic;

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

    -- Primary O REGBUS (P_CLK_I domain)
    PO_REGBUS_RB_RUPDATE : out  std_logic;
    PO_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PO_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PO_REGBUS_RB_RACK    : in   std_logic;

    PO_REGBUS_RB_WUPDATE : out  std_logic;
    PO_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PO_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PO_REGBUS_RB_WACK    : in   std_logic;

    -- Primary P REGBUS (P_CLK_I domain)
    PP_REGBUS_RB_RUPDATE : out  std_logic;
    PP_REGBUS_RB_RADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PP_REGBUS_RB_RDATA   : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PP_REGBUS_RB_RACK    : in   std_logic;

    PP_REGBUS_RB_WUPDATE : out  std_logic;
    PP_REGBUS_RB_WADDR   : out  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    PP_REGBUS_RB_WDATA   : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PP_REGBUS_RB_WACK    : in   std_logic;

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

  -- Secondary-domain fanout (S_CLK_I):  secondary -> the secondary-domain ports, CDC branch (last index)
  constant N_SEC : integer := 2;

  signal sec_rupdate : std_logic_vector(0 to N_SEC-1);
  signal sec_raddr   : regbus_addr_array_t(0 to N_SEC-1);
  signal sec_rdata   : regbus_data_array_t(0 to N_SEC-1);
  signal sec_rack    : std_logic_vector(0 to N_SEC-1);
  signal sec_wupdate : std_logic_vector(0 to N_SEC-1);
  signal sec_waddr   : regbus_addr_array_t(0 to N_SEC-1);
  signal sec_wdata   : regbus_data_array_t(0 to N_SEC-1);
  signal sec_wack    : std_logic_vector(0 to N_SEC-1);

  -- Primary-domain fanout (P_CLK_I):  CDC branch -> the primary-domain ports
  constant N_PRI : integer := 5;

  signal pri_rupdate : std_logic_vector(0 to N_PRI-1);
  signal pri_raddr   : regbus_addr_array_t(0 to N_PRI-1);
  signal pri_rdata   : regbus_data_array_t(0 to N_PRI-1);
  signal pri_rack    : std_logic_vector(0 to N_PRI-1);
  signal pri_wupdate : std_logic_vector(0 to N_PRI-1);
  signal pri_waddr   : regbus_addr_array_t(0 to N_PRI-1);
  signal pri_wdata   : regbus_data_array_t(0 to N_PRI-1);
  signal pri_wack    : std_logic_vector(0 to N_PRI-1);

    -- u_regbus_cdc's P_CLK_I-domain interface
  signal p_rupdate : std_logic;
  signal p_raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal p_rdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal p_rack    : std_logic;
  signal p_wupdate : std_logic;
  signal p_waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal p_wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal p_wack    : std_logic;

  -- additional register stage to aid with timing
  signal s_rupdate_reg : std_logic := '0';
  signal s_raddr_reg   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal s_wupdate_reg : std_logic := '0';
  signal s_waddr_reg   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal s_wdata_reg   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal p_rupdate_reg : std_logic := '0';
  signal p_raddr_reg   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal p_wupdate_reg : std_logic := '0';
  signal p_waddr_reg   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal p_wdata_reg   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');

begin

  --
  process(S_CLK_I, S_RST_I)
  begin
    if (S_RST_I = '1') then
      s_rupdate_reg <= '0';
      s_raddr_reg   <= (others => '0');
      s_wupdate_reg <= '0';
      s_waddr_reg   <= (others => '0');
      s_wdata_reg   <= (others => '0');
    elsif rising_edge(S_CLK_I) then
      s_rupdate_reg <= S_REGBUS_RB_RUPDATE;
      s_raddr_reg   <= S_REGBUS_RB_RADDR;
      s_wupdate_reg <= S_REGBUS_RB_WUPDATE;
      s_waddr_reg   <= S_REGBUS_RB_WADDR;
      s_wdata_reg   <= S_REGBUS_RB_WDATA;
    end if;
  end process;


  -- Secondary-domain fanout:  secondary -> {PA, CDC branch}
  u_fanout_sec : regbus_fanout
    generic map (
      N_PRIMARY => N_SEC
      )
    port map (
      S_REGBUS_RB_RUPDATE  => s_rupdate_reg,
      S_REGBUS_RB_RADDR    => s_raddr_reg,
      S_REGBUS_RB_RDATA    => S_REGBUS_RB_RDATA,
      S_REGBUS_RB_RACK     => S_REGBUS_RB_RACK,

      S_REGBUS_RB_WUPDATE  => s_wupdate_reg,
      S_REGBUS_RB_WADDR    => s_waddr_reg,
      S_REGBUS_RB_WDATA    => s_wdata_reg,
      S_REGBUS_RB_WACK     => S_REGBUS_RB_WACK,

      P_REGBUS_RB_RUPDATE  => sec_rupdate,
      P_REGBUS_RB_RADDR    => sec_raddr,
      P_REGBUS_RB_RDATA    => sec_rdata,
      P_REGBUS_RB_RACK     => sec_rack,

      P_REGBUS_RB_WUPDATE  => sec_wupdate,
      P_REGBUS_RB_WADDR    => sec_waddr,
      P_REGBUS_RB_WDATA    => sec_wdata,
      P_REGBUS_RB_WACK     => sec_wack
      );

  -- PA <-> index 0
  PA_REGBUS_RB_RUPDATE <= sec_rupdate(0);
  PA_REGBUS_RB_RADDR   <= sec_raddr(0);
  sec_rdata(0)          <= PA_REGBUS_RB_RDATA;
  sec_rack(0)           <= PA_REGBUS_RB_RACK;
  PA_REGBUS_RB_WUPDATE <= sec_wupdate(0);
  PA_REGBUS_RB_WADDR   <= sec_waddr(0);
  PA_REGBUS_RB_WDATA   <= sec_wdata(0);
  sec_wack(0)           <= PA_REGBUS_RB_WACK;

  -- PB (not in use) <-> index 1, the CDC branch then index 2
  --PB_REGBUS_RB_RUPDATE <= sec_rupdate(1);
  --PB_REGBUS_RB_RADDR   <= sec_raddr(1);
  --sec_rdata(1)          <= PB_REGBUS_RB_RDATA;
  --sec_rack(1)           <= PB_REGBUS_RB_RACK;
  --PB_REGBUS_RB_WUPDATE <= sec_wupdate(1);
  --PB_REGBUS_RB_WADDR   <= sec_waddr(1);
  --PB_REGBUS_RB_WDATA   <= sec_wdata(1);
  --sec_wack(1)           <= PB_REGBUS_RB_WACK;

  ---------------------------------------------------------------------------
  -- CDC: S_CLK_I -> P_CLK_I strobes, index N_SEC-1. RDATA masking (zero until this
  -- branch's own ack lands) happens inside regbus_cdc. ADDR/WDATA cross as
  -- plain combinational wires below, held stable by the req/ack handshake.
  --
  -- Assumption: every request enters the CDC, including those for PA,
  -- which get no ack from this branch.  After a PA access the S side moves
  -- on while that strobe is still crossing (about 4 P_CLK_I cycles); if the
  -- next request arrived within that time, the strobe would pick up its
  -- address.  But the AXI-Lite from the PS is not that fast to cause this race
  -- condition, so this design chooses simplicity over explicit protection,
  -- with stress tests confirming the assumption.
  ---------------------------------------------------------------------------

  -- u_regbus_cdc: note that this name is used explicitly in constraints file.
  u_regbus_cdc : regbus_cdc
    port map (
      S_CLK_I               => S_CLK_I,
      S_RST_I                => S_RST_I,
      S_REGBUS_RB_RUPDATE   => sec_rupdate(N_SEC-1),
      S_REGBUS_RB_RACK      => sec_rack(N_SEC-1),
      S_REGBUS_RB_RDATA     => sec_rdata(N_SEC-1),
      S_REGBUS_RB_WUPDATE   => sec_wupdate(N_SEC-1),
      S_REGBUS_RB_WACK      => sec_wack(N_SEC-1),

      P_CLK_I                => P_CLK_I,
      P_RST_I                => P_RST_I,
      P_REGBUS_RB_RUPDATE   => p_rupdate,
      P_REGBUS_RB_RACK      => p_rack,
      P_REGBUS_RB_RDATA     => p_rdata,
      P_REGBUS_RB_WUPDATE   => p_wupdate,
      P_REGBUS_RB_WACK      => p_wack
      );

  -- ADDR/WDATA passthrough into the P_CLK_I domain (quasi-static, no register)
  p_raddr <= sec_raddr(N_SEC-1);
  p_waddr <= sec_waddr(N_SEC-1);
  p_wdata <= sec_wdata(N_SEC-1);

  process(P_CLK_I, P_RST_I)
  begin
    if (P_RST_I = '1') then
      p_rupdate_reg <= '0';
      p_raddr_reg   <= (others => '0');
      p_wupdate_reg <= '0';
      p_waddr_reg   <= (others => '0');
      p_wdata_reg   <= (others => '0');
    elsif rising_edge(P_CLK_I) then
      p_rupdate_reg <= p_rupdate;
      p_raddr_reg   <= p_raddr;
      p_wupdate_reg <= p_wupdate;
      p_waddr_reg   <= p_waddr;
      p_wdata_reg   <= p_wdata;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Primary-domain fanout (P_CLK_I domain, behind the CDC)
  ---------------------------------------------------------------------------
  u_fanout_pri : regbus_fanout
    generic map (
      N_PRIMARY => N_PRI
      )
    port map (
      S_REGBUS_RB_RUPDATE  => p_rupdate_reg,
      S_REGBUS_RB_RADDR    => p_raddr_reg,
      S_REGBUS_RB_RDATA    => p_rdata,
      S_REGBUS_RB_RACK     => p_rack,

      S_REGBUS_RB_WUPDATE  => p_wupdate_reg,
      S_REGBUS_RB_WADDR    => p_waddr_reg,
      S_REGBUS_RB_WDATA    => p_wdata_reg,
      S_REGBUS_RB_WACK     => p_wack,

      P_REGBUS_RB_RUPDATE  => pri_rupdate,
      P_REGBUS_RB_RADDR    => pri_raddr,
      P_REGBUS_RB_RDATA    => pri_rdata,
      P_REGBUS_RB_RACK     => pri_rack,

      P_REGBUS_RB_WUPDATE  => pri_wupdate,
      P_REGBUS_RB_WADDR    => pri_waddr,
      P_REGBUS_RB_WDATA    => pri_wdata,
      P_REGBUS_RB_WACK     => pri_wack
      );

  -- PL <-> index 0
  PL_REGBUS_RB_RUPDATE <= pri_rupdate(0);
  PL_REGBUS_RB_RADDR   <= pri_raddr(0);
  pri_rdata(0)         <= PL_REGBUS_RB_RDATA;
  pri_rack(0)          <= PL_REGBUS_RB_RACK;
  PL_REGBUS_RB_WUPDATE <= pri_wupdate(0);
  PL_REGBUS_RB_WADDR   <= pri_waddr(0);
  PL_REGBUS_RB_WDATA   <= pri_wdata(0);
  pri_wack(0)          <= PL_REGBUS_RB_WACK;

  -- PM <-> index 1
  PM_REGBUS_RB_RUPDATE <= pri_rupdate(1);
  PM_REGBUS_RB_RADDR   <= pri_raddr(1);
  pri_rdata(1)         <= PM_REGBUS_RB_RDATA;
  pri_rack(1)          <= PM_REGBUS_RB_RACK;
  PM_REGBUS_RB_WUPDATE <= pri_wupdate(1);
  PM_REGBUS_RB_WADDR   <= pri_waddr(1);
  PM_REGBUS_RB_WDATA   <= pri_wdata(1);
  pri_wack(1)          <= PM_REGBUS_RB_WACK;

  -- PN <-> index 2
  PN_REGBUS_RB_RUPDATE <= pri_rupdate(2);
  PN_REGBUS_RB_RADDR   <= pri_raddr(2);
  pri_rdata(2)         <= PN_REGBUS_RB_RDATA;
  pri_rack(2)          <= PN_REGBUS_RB_RACK;
  PN_REGBUS_RB_WUPDATE <= pri_wupdate(2);
  PN_REGBUS_RB_WADDR   <= pri_waddr(2);
  PN_REGBUS_RB_WDATA   <= pri_wdata(2);
  pri_wack(2)          <= PN_REGBUS_RB_WACK;

  -- PO <-> index 3
  PO_REGBUS_RB_RUPDATE <= pri_rupdate(3);
  PO_REGBUS_RB_RADDR   <= pri_raddr(3);
  pri_rdata(3)         <= PO_REGBUS_RB_RDATA;
  pri_rack(3)          <= PO_REGBUS_RB_RACK;
  PO_REGBUS_RB_WUPDATE <= pri_wupdate(3);
  PO_REGBUS_RB_WADDR   <= pri_waddr(3);
  PO_REGBUS_RB_WDATA   <= pri_wdata(3);
  pri_wack(3)          <= PO_REGBUS_RB_WACK;

  -- PP <-> index 4
  PP_REGBUS_RB_RUPDATE <= pri_rupdate(4);
  PP_REGBUS_RB_RADDR   <= pri_raddr(4);
  pri_rdata(4)         <= PP_REGBUS_RB_RDATA;
  pri_rack(4)          <= PP_REGBUS_RB_RACK;
  PP_REGBUS_RB_WUPDATE <= pri_wupdate(4);
  PP_REGBUS_RB_WADDR   <= pri_waddr(4);
  PP_REGBUS_RB_WDATA   <= pri_wdata(4);
  pri_wack(4)          <= PP_REGBUS_RB_WACK;

  DEBUG <= (others => '0');

end;


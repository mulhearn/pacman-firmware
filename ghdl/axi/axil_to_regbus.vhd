library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simplistic Read: We will not assert ready until a previous read
-- has completed and acknowledged.  This simplification limits
-- throughput, but it doesn't require any buffering.

-- Simplistic Write:
-- We assert awready and wready together, after awvalid and wvalid
-- have been asserted.
--
-- AXI: "A (primary) is not permitted to wait until TREADY is
-- asserted before asserting TVALID. Once TVALID is asserted it must
-- remain asserted until the handshake occurs."
--
-- This simplification limits throughput , but it doesn't require
-- any buffering.

entity axil_to_regbus is
  generic (
    constant C_ADDR_WIDTH : integer := 16;
    constant C_DATA_WIDTH : integer := 32
  );
  port (
    S_AXI_ACLK           : in  std_logic;
    S_AXI_ARESETN        : in  std_logic;
    S_AXI_ARADDR         : in  std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    S_AXI_ARPROT         : in  std_logic_vector(2 downto 0) := (others => '0');
    S_AXI_ARVALID        : in  std_logic;
    S_AXI_ARREADY        : out std_logic;
    S_AXI_RDATA          : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP          : out std_logic_vector(1 downto 0);
    S_AXI_RVALID         : out std_logic;
    S_AXI_RREADY         : in  std_logic;
    S_AXI_AWADDR         : in  std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    S_AXI_AWPROT         : in  std_logic_vector(2 downto 0) := (others => '0');
    S_AXI_AWVALID        : in  std_logic;
    S_AXI_AWREADY        : out std_logic;
    S_AXI_WDATA          : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB          : in  std_logic_vector(C_DATA_WIDTH/8-1 downto 0) := (others => '0');
    S_AXI_WVALID         : in  std_logic;
    S_AXI_WREADY         : out std_logic;
    S_AXI_BRESP          : out std_logic_vector(1 downto 0);
    S_AXI_BVALID         : out std_logic;
    S_AXI_BREADY         : in  std_logic;

    P_REGBUS_RB_RUPDATE  : out std_logic;
    P_REGBUS_RB_RADDR    : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    P_REGBUS_RB_RDATA    : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
    P_REGBUS_RB_RACK     : in  std_logic;

    P_REGBUS_RB_WUPDATE  : out std_logic;
    P_REGBUS_RB_WADDR    : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
    P_REGBUS_RB_WDATA    : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
    P_REGBUS_RB_WACK     : in  std_logic
    );
end;

architecture behavioral of axil_to_regbus is
  signal clk       : std_logic;
  signal rst       : std_logic;

  -- Sames states are defined for both reads and writes:
  --   IDLE        wait for the AXI request beat(s)
  --   STROBE      one cycle: pulse the regbus update, capture addr/data
  --   WAIT_ACK    wait for the regbus ack
  --   WAIT_READY  drive the AXI response, wait for the master to take it

  type state_t is (IDLE, STROBE, WAIT_ACK, WAIT_READY);

  signal rd_state      : state_t := IDLE;
  signal rd_state_next : state_t;

  signal wr_state      : state_t := IDLE;
  signal wr_state_next : state_t;

  -- captured address and data registers:
  signal raddr : std_logic_vector(C_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal rdata : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');
  signal waddr : std_logic_vector(C_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal wdata : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');

begin
  -- register AXI outputs:
  clk <= S_AXI_ACLK;
  rst <= not S_AXI_ARESETN;

  -------------------
  -- Read:
  -------------------

  -- determine next read state (combinatoric)
  process(rd_state, S_AXI_ARVALID, P_REGBUS_RB_RACK, S_AXI_RREADY)
  begin
    rd_state_next <= rd_state;
    case rd_state is
      when IDLE =>
        if (S_AXI_ARVALID = '1') then
          rd_state_next <= STROBE;
        end if;
      when STROBE =>
        rd_state_next <= WAIT_ACK; -- unconditional, one-cycle strobe
      when WAIT_ACK =>
        if (P_REGBUS_RB_RACK = '1') then
          rd_state_next <= WAIT_READY;
        end if;
      when WAIT_READY =>
        if (S_AXI_RREADY = '1') then
          rd_state_next <= IDLE;
        end if;
    end case;
  end process;

  -- state register
  process(clk)
  begin
    if (rst = '1') then
      rd_state <= IDLE;
    elsif rising_edge(clk) then
      rd_state <= rd_state_next;
    end if;
  end process;

  -- register address and data: capture address entering STROBE, data at ack
  process(clk)
  begin
    if rising_edge(clk) then
      if (rd_state_next = STROBE) then
        raddr <= S_AXI_ARADDR;
      end if;
      if (rd_state = WAIT_ACK and P_REGBUS_RB_RACK = '1') then
        rdata <= P_REGBUS_RB_RDATA;       -- latch while regbus holds it
      end if;
    end if;
  end process;

  -- register outputs depending on the next state, so that there is no lag:
  --    outputs are zero except:
  --      STROBE:      ARREADY = RUPDATE = 1 (for exactly one clock cycle)
  --      WAIT_READY:  RVALID = 1 (until RREADY=1)
  process(clk)
  begin
    if (rst = '1') then
      S_AXI_ARREADY       <= '0';
      S_AXI_RVALID        <= '0';
      P_REGBUS_RB_RUPDATE <= '0';
    elsif rising_edge(clk) then
      S_AXI_ARREADY       <= '0';
      S_AXI_RVALID        <= '0';
      P_REGBUS_RB_RUPDATE <= '0';
      case rd_state_next is
        when STROBE =>
          S_AXI_ARREADY <= '1';
          P_REGBUS_RB_RUPDATE <= '1';
        when WAIT_READY =>
          S_AXI_RVALID <= '1';
        when others =>
          null;
      end case;
    end if;
  end process;

  S_AXI_RDATA       <= rdata;
  S_AXI_RRESP       <= (others => '0');
  P_REGBUS_RB_RADDR <= raddr;

  -------------------
  -- Write:
  -------------------

  -- determine next write state (combinatoric)
  process(wr_state, S_AXI_AWVALID, S_AXI_WVALID, P_REGBUS_RB_WACK, S_AXI_BREADY)
  begin
    wr_state_next <= wr_state;
    case wr_state is
      when IDLE =>
        if (S_AXI_AWVALID = '1' and S_AXI_WVALID = '1') then
          wr_state_next <= STROBE;
        end if;
      when STROBE =>
        wr_state_next <= WAIT_ACK; -- unconditional, one-cycle strobe
      when WAIT_ACK =>
        if (P_REGBUS_RB_WACK = '1') then
          wr_state_next <= WAIT_READY;
        end if;
      when WAIT_READY =>
        if (S_AXI_BREADY = '1') then
          wr_state_next <= IDLE;
        end if;
    end case;
  end process;

  -- state register
  process(clk)
  begin
    if (rst = '1') then
      wr_state <= IDLE;
    elsif rising_edge(clk) then
      wr_state <= wr_state_next;
    end if;
  end process;

  -- register address and data:  capture both upon entering STROBE
  process(clk)
  begin
    if rising_edge(clk) then
      if (wr_state_next = STROBE) then
        waddr <= S_AXI_AWADDR;
        wdata <= S_AXI_WDATA;
      end if;
    end if;
  end process;

  -- register outputs depending on the next state, so that there is no lag:
  --    outputs are zero except:
  --      STROBE:      AWREADY = WREADY = WUPDATE = 1 (for exactly one clock cycle)
  --      WAIT_READY:  BVALID = 1 (until BREADY=1)
  process(clk)
  begin
    if (rst = '1') then
      S_AXI_AWREADY       <= '0';
      S_AXI_WREADY        <= '0';
      S_AXI_BVALID        <= '0';
      P_REGBUS_RB_WUPDATE <= '0';
    elsif rising_edge(clk) then
      S_AXI_AWREADY       <= '0';
      S_AXI_WREADY        <= '0';
      S_AXI_BVALID        <= '0';
      P_REGBUS_RB_WUPDATE <= '0';
      case wr_state_next is
        when STROBE     =>
          S_AXI_AWREADY       <= '1';
          S_AXI_WREADY        <= '1';
          P_REGBUS_RB_WUPDATE <= '1';
        when WAIT_READY =>
          S_AXI_BVALID <= '1';
        when others =>
          null;
      end case;
    end if;
  end process;

  S_AXI_BRESP       <= (others => '0');
  P_REGBUS_RB_WADDR <= waddr;
  P_REGBUS_RB_WDATA <= wdata;


end;

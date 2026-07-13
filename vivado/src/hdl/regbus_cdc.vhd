library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity regbus_cdc is
  port (
    -- Secondary REGBUS:
    S_CLK_I	         : in std_logic;
    S_RST_I	         : in std_logic;

    S_REGBUS_RB_RUPDATE  : in   std_logic;
    S_REGBUS_RB_RDATA    : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RACK     : out  std_logic;

    S_REGBUS_RB_WUPDATE  : in   std_logic;
    S_REGBUS_RB_WACK     : out  std_logic;

    -- Primary REGBUS
    P_CLK_I	         : in std_logic;
    P_RST_I	         : in std_logic;

    P_REGBUS_RB_RUPDATE  : out  std_logic;
    P_REGBUS_RB_RDATA    : in   std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    P_REGBUS_RB_RACK     : in   std_logic;

    P_REGBUS_RB_WUPDATE  : out  std_logic;
    P_REGBUS_RB_WACK     : in   std_logic
    );
end;


architecture behavioral of regbus_cdc is

  attribute ASYNC_REG : string;

  -- read request: S domain -> P domain
  signal rd_req_tgl_s   : std_logic := '0';
  signal rd_req_sync_p  : std_logic_vector(3 downto 0) := (others => '0');
  signal rd_req_pulse_p : std_logic;

  -- read ack: P domain -> S domain
  signal rd_ack_tgl_p   : std_logic := '0';
  signal rd_ack_sync_s  : std_logic_vector(3 downto 0) := (others => '0');
  signal rd_ack_pulse_s : std_logic;

  -- write request: S domain -> P domain
  signal wr_req_tgl_s   : std_logic := '0';
  signal wr_req_sync_p  : std_logic_vector(3 downto 0) := (others => '0');
  signal wr_req_pulse_p : std_logic;

  -- write ack: P domain -> S domain
  signal wr_ack_tgl_p   : std_logic := '0';
  signal wr_ack_sync_s  : std_logic_vector(3 downto 0) := (others => '0');
  signal wr_ack_pulse_s : std_logic;

  signal rd_valid_s : std_logic := '0';

  attribute ASYNC_REG of rd_req_sync_p : signal is "TRUE";
  attribute ASYNC_REG of rd_ack_sync_s : signal is "TRUE";
  attribute ASYNC_REG of wr_req_sync_p : signal is "TRUE";
  attribute ASYNC_REG of wr_ack_sync_s : signal is "TRUE";

begin

  -----------------------------------------------------------------
  -- read request: toggle on S_REGBUS_RB_RUPDATE, sync+edge-detect in P domain
  -----------------------------------------------------------------
  process(S_CLK_I, S_RST_I)
  begin
    if (S_RST_I = '1') then
      rd_req_tgl_s <= '0';
    elsif rising_edge(S_CLK_I) then
      if (S_REGBUS_RB_RUPDATE = '1') then
        rd_req_tgl_s <= not rd_req_tgl_s;
      end if;
    end if;
  end process;

  process(P_CLK_I, P_RST_I)
  begin
    if (P_RST_I = '1') then
      rd_req_sync_p <= (others => '0');
    elsif rising_edge(P_CLK_I) then
      rd_req_sync_p <= rd_req_sync_p(2 downto 0) & rd_req_tgl_s;
    end if;
  end process;

  rd_req_pulse_p <= rd_req_sync_p(3) xor rd_req_sync_p(2);

  -----------------------------------------------------------------
  -- read ack: toggle on P_REGBUS_RB_RACK, sync+edge-detect in S domain
  -----------------------------------------------------------------
  process(P_CLK_I, P_RST_I)
  begin
    if (P_RST_I = '1') then
      rd_ack_tgl_p <= '0';
    elsif rising_edge(P_CLK_I) then
      if (P_REGBUS_RB_RACK = '1') then
        rd_ack_tgl_p <= not rd_ack_tgl_p;
      end if;
    end if;
  end process;

  process(S_CLK_I, S_RST_I)
  begin
    if (S_RST_I = '1') then
      rd_ack_sync_s <= (others => '0');
    elsif rising_edge(S_CLK_I) then
      rd_ack_sync_s <= rd_ack_sync_s(2 downto 0) & rd_ack_tgl_p;
    end if;
  end process;

  rd_ack_pulse_s <= rd_ack_sync_s(3) xor rd_ack_sync_s(2);

  -----------------------------------------------------------------
  -- write request: toggle on S_REGBUS_RB_WUPDATE, sync+edge-detect in P domain
  -----------------------------------------------------------------
  process(S_CLK_I, S_RST_I)
  begin
    if (S_RST_I = '1') then
      wr_req_tgl_s <= '0';
    elsif rising_edge(S_CLK_I) then
      if (S_REGBUS_RB_WUPDATE = '1') then
        wr_req_tgl_s <= not wr_req_tgl_s;
      end if;
    end if;
  end process;

  process(P_CLK_I, P_RST_I)
  begin
    if (P_RST_I = '1') then
      wr_req_sync_p <= (others => '0');
    elsif rising_edge(P_CLK_I) then
      wr_req_sync_p <= wr_req_sync_p(2 downto 0) & wr_req_tgl_s;
    end if;
  end process;

  wr_req_pulse_p <= wr_req_sync_p(3) xor wr_req_sync_p(2);

  -----------------------------------------------------------------
  -- write ack: toggle on P_REGBUS_RB_WACK, sync+edge-detect in S domain
  -----------------------------------------------------------------
  process(P_CLK_I, P_RST_I)
  begin
    if (P_RST_I = '1') then
      wr_ack_tgl_p <= '0';
    elsif rising_edge(P_CLK_I) then
      if (P_REGBUS_RB_WACK = '1') then
        wr_ack_tgl_p <= not wr_ack_tgl_p;
      end if;
    end if;
  end process;

  process(S_CLK_I, S_RST_I)
  begin
    if (S_RST_I = '1') then
      wr_ack_sync_s <= (others => '0');
    elsif rising_edge(S_CLK_I) then
      wr_ack_sync_s <= wr_ack_sync_s(2 downto 0) & wr_ack_tgl_p;
    end if;
  end process;

  wr_ack_pulse_s <= wr_ack_sync_s(3) xor wr_ack_sync_s(2);

  process(S_CLK_I, S_RST_I)
  begin
    if (S_RST_I = '1') then
      rd_valid_s <= '0';
    elsif rising_edge(S_CLK_I) then
      if (S_REGBUS_RB_RUPDATE = '1') then
        rd_valid_s <= '0';
      elsif (rd_ack_pulse_s = '1') then
        rd_valid_s <= '1';
      end if;
    end if;
  end process;

  P_REGBUS_RB_RUPDATE <= rd_req_pulse_p;
  S_REGBUS_RB_RACK    <= rd_ack_pulse_s;
  S_REGBUS_RB_RDATA   <= P_REGBUS_RB_RDATA when (rd_valid_s = '1' or rd_ack_pulse_s = '1') else (others => '0');
  S_REGBUS_RB_WACK    <= wr_ack_pulse_s;
  P_REGBUS_RB_WUPDATE <= wr_req_pulse_p;

end;

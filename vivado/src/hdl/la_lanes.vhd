library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- la_lanes:  the logic analyzer's inputs, lanes and sample, and the sample strobe.
--
-- Every stage is registered, and every input passes the same number of stages, so a sample holds the inputs as
-- they were at one clock (the timestamp too):
--   inputs     registered twice (all synchronous:  PISO as synchronized by rx_unit)
--   lanes      4 bits each, registered:  tile lanes A-D (TILE_I:  the tile of each lane, 0-9;  10-15:  zeros), and
--              the units' status
--   sample     32 bits, registered:  the final mux, 8 nibbles A-H, nibble n (sample bits 4n+3 to 4n) the lane
--              chosen by MUX_SELECT_I(n)
--
--   lane  0      zero
--   lane  1, 2   tile lane A:  PISO 0-3, POSI 0-3 of its tile (UART 4t to 4t+3, lowest bit first)
--   lane  3, 4   tile lane B          lane  9   G A, H A, G B, H B
--   lane  5, 6   tile lane C          lane 10   G C, H C, G D, H D
--   lane  7, 8   tile lane D          lane 11-16  ATC, RX, TX status, bits 3-0 (_LOWER) then 7-4 (_UPPER)
--   lane 17-31   zero
--
-- Sample strobe (SE_O, with the sample it belongs to):  every PERIOD clocks (free running), or at PHASE,
-- PHASE+PERIOD, ... clocks after each BAUD strobe (LOCK_I, BAUD locked).  PERIOD 0:  no samples.

entity la_lanes is
  port (
    CLK_I          : in  std_logic;
    RST_I          : in  std_logic;

    -- inputs
    PISO_I         : in  std_logic_vector(C_NUM_UART-1 downto 0);
    POSI_I         : in  std_logic_vector(C_NUM_UART-1 downto 0);
    G_I            : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    H_I            : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    BAUD_I         : in  std_logic;
    ATC_STATUS_I   : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
    RX_STATUS_I    : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
    TX_STATUS_I    : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
    TIMESTAMP_I    : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);

    -- configuration (registers)
    TILE_I         : in  std_logic_vector(4*4-1 downto 0);    -- lane x (A-D = 0-3):  TILE_I(4x+3 downto 4x)
    MUX_SELECT_I   : in  std_logic_vector(8*5-1 downto 0);    -- nibble n (A-H = 0-7):  MUX_SELECT_I(5n+4 downto 5n)
    PERIOD_I       : in  std_logic_vector(31 downto 0);
    PHASE_I        : in  std_logic_vector(31 downto 0);
    LOCK_I         : in  std_logic;                           -- 1:  BAUD locked

    -- sample, its strobe and timestamp
    SAMPLE_O       : out std_logic_vector(31 downto 0);
    SE_O           : out std_logic;
    TS_O           : out std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0)
  );
end la_lanes;

architecture rtl of la_lanes is
  constant C_UART_PER_TILE : integer := C_NUM_UART / C_NUM_TILE;
  constant C_IN_WIDTH      : integer := 2*C_NUM_UART + 2*C_NUM_TILE + 1 + 3*C_STATUS_BITS;

  -- input stages
  signal in_all, in_s1, in_s2 : std_logic_vector(C_IN_WIDTH-1 downto 0) := (others => '0');
  signal ts_s1, ts_s2, ts_l, ts_r  : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0) := (others => '0');

  signal piso_s2, posi_s2 : std_logic_vector(C_NUM_UART-1 downto 0);
  signal g_s2, h_s2      : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal baud_s2         : std_logic;
  signal status_s2       : std_logic_vector(3*C_STATUS_BITS-1 downto 0);   -- ATC, RX, TX

  -- lanes (registered)
  type nibble4_t is array (0 to 3) of std_logic_vector(3 downto 0);
  signal piso_l, posi_l  : nibble4_t := (others => (others => '0'));
  signal g_l, h_l        : std_logic_vector(3 downto 0) := (others => '0');
  signal status_l        : std_logic_vector(3*C_STATUS_BITS-1 downto 0) := (others => '0');
  signal baud_l          : std_logic := '0';
  type lanes_t is array (0 to 31) of std_logic_vector(3 downto 0);
  signal lanes           : lanes_t;

  -- sample (registered), strobe aligned with it
  signal sample_r : std_logic_vector(31 downto 0) := (others => '0');
  signal se       : std_logic;
  signal se_r     : std_logic := '0';
  signal cnt      : unsigned(31 downto 0) := (others => '0');
begin

  in_all <= TX_STATUS_I & RX_STATUS_I & ATC_STATUS_I & BAUD_I & H_I & G_I & POSI_I & PISO_I;

  process(CLK_I, RST_I)
  begin
    if (RST_I = '1') then
      in_s1 <= (others => '0');
      in_s2 <= (others => '0');
      ts_s1 <= (others => '0');
      ts_s2 <= (others => '0');
    elsif rising_edge(CLK_I) then
      in_s1 <= in_all;
      in_s2 <= in_s1;
      ts_s1 <= TIMESTAMP_I;
      ts_s2 <= ts_s1;
    end if;
  end process;

  piso_s2   <= in_s2(C_NUM_UART-1 downto 0);
  posi_s2   <= in_s2(2*C_NUM_UART-1 downto C_NUM_UART);
  g_s2      <= in_s2(2*C_NUM_UART+C_NUM_TILE-1 downto 2*C_NUM_UART);
  h_s2      <= in_s2(2*C_NUM_UART+2*C_NUM_TILE-1 downto 2*C_NUM_UART+C_NUM_TILE);
  baud_s2   <= in_s2(2*C_NUM_UART+2*C_NUM_TILE);
  status_s2 <= in_s2(C_IN_WIDTH-1 downto 2*C_NUM_UART+2*C_NUM_TILE+1);

  -- lanes
  process(CLK_I, RST_I)
    variable t : integer;
  begin
    if (RST_I = '1') then
      piso_l   <= (others => (others => '0'));
      posi_l   <= (others => (others => '0'));
      g_l      <= (others => '0');
      h_l      <= (others => '0');
      status_l <= (others => '0');
      baud_l   <= '0';
      ts_l     <= (others => '0');
    elsif rising_edge(CLK_I) then
      for x in 0 to 3 loop
        t := to_integer(unsigned(TILE_I(4*x+3 downto 4*x)));
        if t < C_NUM_TILE then
          piso_l(x) <= piso_s2(C_UART_PER_TILE*t+3 downto C_UART_PER_TILE*t);
          posi_l(x) <= posi_s2(C_UART_PER_TILE*t+3 downto C_UART_PER_TILE*t);
          g_l(x)    <= g_s2(t);
          h_l(x)    <= h_s2(t);
        else
          piso_l(x) <= (others => '0');
          posi_l(x) <= (others => '0');
          g_l(x)    <= '0';
          h_l(x)    <= '0';
        end if;
      end loop;
      status_l <= status_s2;
      baud_l   <= baud_s2;
      ts_l     <= ts_s2;
    end if;
  end process;

  lanes(0) <= (others => '0');
  lane_tiles: for x in 0 to 3 generate
    lanes(1 + 2*x) <= piso_l(x);
    lanes(2 + 2*x) <= posi_l(x);
  end generate;
  lanes(9)  <= h_l(1) & g_l(1) & h_l(0) & g_l(0);
  lanes(10) <= h_l(3) & g_l(3) & h_l(2) & g_l(2);
  lane_status: for k in 0 to 3*C_STATUS_BITS/4-1 generate
    lanes(11 + k) <= status_l(4*k+3 downto 4*k);
  end generate;
  lanes(11 + 3*C_STATUS_BITS/4 to 31) <= (others => (others => '0'));

  -- sample strobe, for the lanes as they are now (so it lines up with sample_r, registered below)
  se <= '0' when unsigned(PERIOD_I) = 0 else
        '1' when LOCK_I = '1' and baud_l = '1' and unsigned(PHASE_I) = 0 else
        '0' when LOCK_I = '1' and baud_l = '1' else
        '1' when cnt = 0 else
        '0';

  process(CLK_I, RST_I)
  begin
    if (RST_I = '1') then
      cnt <= (others => '0');
    elsif rising_edge(CLK_I) then
      if unsigned(PERIOD_I) = 0 then
        cnt <= (others => '0');
      elsif LOCK_I = '1' and baud_l = '1' then
        if unsigned(PHASE_I) = 0 then
          cnt <= unsigned(PERIOD_I) - 1;
        else
          cnt <= unsigned(PHASE_I) - 1;
        end if;
      elsif cnt = 0 then
        cnt <= unsigned(PERIOD_I) - 1;
      else
        cnt <= cnt - 1;
      end if;
    end if;
  end process;

  -- sample:  the final mux
  process(CLK_I, RST_I)
  begin
    if (RST_I = '1') then
      sample_r <= (others => '0');
      se_r     <= '0';
      ts_r     <= (others => '0');
    elsif rising_edge(CLK_I) then
      for n in 0 to 7 loop
        sample_r(4*n+3 downto 4*n) <= lanes(to_integer(unsigned(MUX_SELECT_I(5*n+4 downto 5*n))));
      end loop;
      se_r <= se;
      ts_r <= ts_l;
    end if;
  end process;

  SAMPLE_O <= sample_r;
  SE_O     <= se_r;
  TS_O     <= ts_r;

end rtl;

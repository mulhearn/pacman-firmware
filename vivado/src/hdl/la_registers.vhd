library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;

entity la_registers is
  generic (
    C_DEPTH             : integer := 32768
  );
  port (
    CLK_I               : in std_logic;
    RST_I               : in std_logic;

    S_REGBUS_RB_RUPDATE : in  std_logic;
    S_REGBUS_RB_RADDR   : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_RDATA   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RACK    : out std_logic;

    S_REGBUS_RB_WUPDATE : in  std_logic;
    S_REGBUS_RB_WADDR   : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_WDATA   : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_WACK    : out std_logic;

    -- configuration
    TILE_O              : out std_logic_vector(4*4-1 downto 0);
    MUX_SELECT_O        : out std_logic_vector(8*5-1 downto 0);
    PERIOD_O            : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PHASE_O             : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    MODE_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    TRIG_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    POST_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    -- commands (one-clock strobes on a write)
    ARM_O               : out std_logic;
    FORCE_O             : out std_logic;
    START_O             : out std_logic;
    NEXT_O              : out std_logic;
    -- status and readout
    STATUS_I            : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    TRIG_POS_I          : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    COUNT_I             : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    TS_I                : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    DATA_I              : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
  );
end entity la_registers;

architecture behavioral of la_registers is
  signal clk      : std_logic;
  signal rst      : std_logic;

  signal rupdate  : std_logic;
  signal raddr    : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal rdata    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal rack     : std_logic := '0';

  signal wupdate  : std_logic;
  signal waddr    : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
  signal wdata    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal wack     : std_logic := '0';

  -- registers
  type reg_array_t is array (natural range <>) of std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal tile     : reg_array_t(0 to 3) := (others => (others => '0'));
  signal mux_select : reg_array_t(0 to 7) := (others => (others => '0'));
  signal period   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := x"00000001";
  signal phase    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal mode     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := x"00000002";
  signal trig     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal post     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal arm, frc, start, nxt : std_logic := '0';

begin
  --inputs:
  clk       <= CLK_I;
  rst       <= RST_I;

  --output registers
  tile_out: for x in 0 to 3 generate
    TILE_O(4*x+3 downto 4*x) <= tile(x)(3 downto 0);
  end generate;
  mux_select_out: for n in 0 to 7 generate
    MUX_SELECT_O(5*n+4 downto 5*n) <= mux_select(n)(4 downto 0);
  end generate;
  PERIOD_O  <= period;
  PHASE_O   <= phase;
  MODE_O    <= mode;
  TRIG_O    <= trig;
  POST_O    <= post;
  ARM_O     <= arm;
  FORCE_O   <= frc;
  START_O   <= start;
  NEXT_O    <= nxt;

  --REGBUS--
  --outputs:
  S_REGBUS_RB_RDATA      <= rdata;
  S_REGBUS_RB_RACK       <= rack;
  S_REGBUS_RB_WACK       <= wack;
  --inputs: (already registered at preceding stage)
  rupdate  <= S_REGBUS_RB_RUPDATE;
  raddr    <= S_REGBUS_RB_RADDR;
  wupdate  <= S_REGBUS_RB_WUPDATE;
  waddr    <= S_REGBUS_RB_WADDR;
  wdata    <= S_REGBUS_RB_WDATA;

  -- Handle Read Request:
  process(clk,rst)
    variable scope   : integer;
    variable reg     : integer;
  begin
    if (rst = '1') then
      rdata <= x"00000000";
      rack <= '0';
    elsif (rising_edge(clk)) then
      rack <= '0';
      if (rupdate='1') then
        scope := to_integer(unsigned(raddr(15 downto 12)));
        reg   := to_integer(unsigned(raddr(11 downto 0)));
        if (scope=C_SCOPE_LA) then
          rack  <= '1';
          if (reg=C_ADDR_LA_PERIOD) then
            rdata <= period;
          elsif (reg=C_ADDR_LA_PHASE) then
            rdata <= phase;
          elsif (reg=C_ADDR_LA_MODE) then
            rdata <= mode;
          elsif (reg=C_ADDR_LA_TRIG) then
            rdata <= trig;
          elsif (reg=C_ADDR_LA_POST) then
            rdata <= post;
          elsif (reg=C_ADDR_LA_STATUS) then
            rdata <= STATUS_I;
          elsif (reg=C_ADDR_LA_TRIG_POS) then
            rdata <= TRIG_POS_I;
          elsif (reg=C_ADDR_LA_COUNT) then
            rdata <= COUNT_I;
          elsif (reg=C_ADDR_LA_DEPTH) then
            rdata <= std_logic_vector(to_unsigned(C_DEPTH, C_RB_DATA_WIDTH));
          elsif (reg=C_ADDR_LA_TS_LOWER) then
            rdata <= TS_I(31 downto 0);
          elsif (reg=C_ADDR_LA_TS_UPPER) then
            rdata <= TS_I(63 downto 32);
          elsif (reg=C_ADDR_LA_DATA) then
            rdata <= DATA_I;
          elsif (reg>=C_ADDR_LA_TILE_A and reg<=C_ADDR_LA_TILE_D and reg mod 4=0) then
            rdata <= tile((reg-C_ADDR_LA_TILE_A)/4);
          elsif (reg>=C_ADDR_LA_MUX_SELECT_A and reg<=C_ADDR_LA_MUX_SELECT_H and reg mod 4=0) then
            rdata <= mux_select((reg-C_ADDR_LA_MUX_SELECT_A)/4);
          else
            -- this is an error, invalid register
            rdata <= x"EEEEEEEE";
            rack  <= '0';
          end if;
        else
          -- this is not an error, just a request outside our scope/role
          rdata <= x"00000000";
          rack  <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Handle Write Request:
  process(clk,rst)
    variable scope   : integer;
    variable reg     : integer;
  begin
    if (rst = '1') then
      tile      <= (others => (others => '0'));
      mux_select <= (others => (others => '0'));
      period    <= x"00000001";
      phase     <= x"00000000";
      mode      <= x"00000002";
      trig      <= x"00000000";
      post      <= x"00000000";
      arm       <= '0';
      frc       <= '0';
      start     <= '0';
      nxt       <= '0';
      wack      <= '0';
    elsif (rising_edge(clk)) then
      arm   <= '0';
      frc   <= '0';
      start <= '0';
      nxt   <= '0';
      if (wupdate='0') then
        wack  <= '0';
      else
        wack  <= '0';
        scope := to_integer(unsigned(waddr(15 downto 12)));
        reg   := to_integer(unsigned(waddr(11 downto 0)));
        if (scope=C_SCOPE_LA) then
          wack <= '1';
          if (reg=C_ADDR_LA_PERIOD) then
            period    <= wdata;
          elsif (reg=C_ADDR_LA_PHASE) then
            phase     <= wdata;
          elsif (reg=C_ADDR_LA_MODE) then
            mode      <= x"0000000" & "00" & wdata(1 downto 0);
          elsif (reg=C_ADDR_LA_TRIG) then
            trig      <= x"00000" & "0" & wdata(10 downto 8) & "000" & wdata(4 downto 0);
          elsif (reg=C_ADDR_LA_POST) then
            post      <= wdata;
          elsif (reg=C_ADDR_LA_ARM) then
            arm       <= '1';
          elsif (reg=C_ADDR_LA_FORCE) then
            frc       <= '1';
          elsif (reg=C_ADDR_LA_START) then
            start     <= '1';
          elsif (reg=C_ADDR_LA_NEXT) then
            nxt       <= '1';
          elsif (reg>=C_ADDR_LA_TILE_A and reg<=C_ADDR_LA_TILE_D and reg mod 4=0) then
            tile((reg-C_ADDR_LA_TILE_A)/4) <= x"0000000" & wdata(3 downto 0);
          elsif (reg>=C_ADDR_LA_MUX_SELECT_A and reg<=C_ADDR_LA_MUX_SELECT_H and reg mod 4=0) then
            mux_select((reg-C_ADDR_LA_MUX_SELECT_A)/4) <= x"000000" & "000" & wdata(4 downto 0);
          else
            -- invalid or read-only register:  no ack
            wack <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
end;

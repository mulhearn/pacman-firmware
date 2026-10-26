library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;

entity adc_registers is
  generic (
    C_DEPTH             : integer := 16384
  );
  port (
    CLK_I	        : in std_logic;
    RST_I	        : in std_logic;

    S_REGBUS_RB_RUPDATE : in  std_logic;
    S_REGBUS_RB_RADDR	: in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_RDATA	: out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RACK    : out std_logic;

    S_REGBUS_RB_WUPDATE : in  std_logic;
    S_REGBUS_RB_WADDR	: in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_WDATA	: in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_WACK    : out std_logic;

    CONFIG_O            : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    --STATUS_I            : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    LOOK_I              : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

    -- emulator, mux, comparator
    EMUL_MIN_O          : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    EMUL_MAX_O          : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    EMUL_STEP_O         : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    EMUL_PERIOD_O       : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    MUX_SELECT_O        : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    CMP_THRESH_O        : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    CMP_SWING_O         : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    CMP_LEVEL_I         : in  std_logic;

    -- capture:  configuration
    PERIOD_O            : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    MODE_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    TRIG_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    POST_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    -- capture:  commands (one-clock strobes on a write)
    ARM_O               : out std_logic;
    FORCE_O             : out std_logic;
    START_O             : out std_logic;
    NEXT_O              : out std_logic;
    -- capture:  status and readout
    CAPTURE_STATUS_I    : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    TRIG_POS_I          : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    COUNT_I             : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    TS_I                : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    DATA_I              : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
    );
end entity adc_registers;

architecture behavioral of adc_registers is
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
  signal config   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');

  signal emul_min    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal emul_max    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal emul_step   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal emul_period : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal mux_select  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal cmp_thresh  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal cmp_swing   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');

  signal period   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := x"00000001";
  signal mode     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := x"00000002";
  signal trig     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal post     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal arm, frc, start, nxt : std_logic := '0';

begin
  --inputs:
  clk       <= CLK_I;
  rst       <= RST_I;

  --output registers
  CONFIG_O  <= config;

  EMUL_MIN_O    <= emul_min;
  EMUL_MAX_O    <= emul_max;
  EMUL_STEP_O   <= emul_step;
  EMUL_PERIOD_O <= emul_period;
  MUX_SELECT_O  <= mux_select;
  CMP_THRESH_O  <= cmp_thresh;
  CMP_SWING_O   <= cmp_swing;

  PERIOD_O  <= period;
  MODE_O    <= mode;
  TRIG_O    <= trig;
  POST_O    <= post;
  ARM_O     <= arm;
  FORCE_O   <= frc;
  START_O   <= start;
  NEXT_O    <= nxt;

  --REGBUS--
  --outputs:
  S_REGBUS_RB_RDATA	 <= rdata;
  S_REGBUS_RB_RACK	 <= rack;
  S_REGBUS_RB_WACK	 <= wack;
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
        if (scope=C_SCOPE_ADC) then
          rack  <= '1';
          if (reg=C_ADDR_ADC_STATUS) then
            rdata <= x"00000ADC";
          elsif (reg=C_ADDR_ADC_LOOK) then
            rdata <= LOOK_I;
          elsif (reg=C_ADDR_ADC_CONFIG) then
            rdata <= config;
          elsif (reg=C_ADDR_ADC_EMUL_MIN) then
            rdata <= emul_min;
          elsif (reg=C_ADDR_ADC_EMUL_MAX) then
            rdata <= emul_max;
          elsif (reg=C_ADDR_ADC_EMUL_STEP) then
            rdata <= emul_step;
          elsif (reg=C_ADDR_ADC_EMUL_PERIOD) then
            rdata <= emul_period;
          elsif (reg=C_ADDR_ADC_MUX_SELECT) then
            rdata <= mux_select;
          elsif (reg=C_ADDR_ADC_CMP_THRESH) then
            rdata <= cmp_thresh;
          elsif (reg=C_ADDR_ADC_CMP_SWING) then
            rdata <= cmp_swing;
          elsif (reg=C_ADDR_ADC_CMP_LEVEL) then
            rdata <= (C_RB_DATA_WIDTH-1 downto 1 => '0') & CMP_LEVEL_I;
          elsif (reg=C_ADDR_ADC_PERIOD) then
            rdata <= period;
          elsif (reg=C_ADDR_ADC_MODE) then
            rdata <= mode;
          elsif (reg=C_ADDR_ADC_TRIG) then
            rdata <= trig;
          elsif (reg=C_ADDR_ADC_POST) then
            rdata <= post;
          elsif (reg=C_ADDR_ADC_CAPTURE_STATUS) then
            rdata <= CAPTURE_STATUS_I;
          elsif (reg=C_ADDR_ADC_TRIG_POS) then
            rdata <= TRIG_POS_I;
          elsif (reg=C_ADDR_ADC_COUNT) then
            rdata <= COUNT_I;
          elsif (reg=C_ADDR_ADC_DEPTH) then
            rdata <= std_logic_vector(to_unsigned(C_DEPTH, C_RB_DATA_WIDTH));
          elsif (reg=C_ADDR_ADC_TS_LOWER) then
            rdata <= TS_I(31 downto 0);
          elsif (reg=C_ADDR_ADC_TS_UPPER) then
            rdata <= TS_I(63 downto 32);
          elsif (reg=C_ADDR_ADC_DATA) then
            rdata <= DATA_I;
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
      config      <= x"00000000";
      emul_min    <= x"00000000";
      emul_max    <= x"00000000";
      emul_step   <= x"00000000";
      emul_period <= x"00000000";
      mux_select  <= x"00000000";
      cmp_thresh  <= x"00000000";
      cmp_swing   <= x"00000000";
      period      <= x"00000001";
      mode        <= x"00000002";
      trig        <= x"00000000";
      post        <= x"00000000";
      arm         <= '0';
      frc         <= '0';
      start       <= '0';
      nxt         <= '0';
      wack        <= '0';
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
        if (scope=C_SCOPE_ADC) then
          wack <= '1';
          if (reg=C_ADDR_ADC_CONFIG) then
            config      <= wdata;
          elsif (reg=C_ADDR_ADC_EMUL_MIN) then
            emul_min    <= x"00000" & wdata(11 downto 0);
          elsif (reg=C_ADDR_ADC_EMUL_MAX) then
            emul_max    <= x"00000" & wdata(11 downto 0);
          elsif (reg=C_ADDR_ADC_EMUL_STEP) then
            emul_step   <= x"0000" & "000" & wdata(12 downto 0);
          elsif (reg=C_ADDR_ADC_EMUL_PERIOD) then
            emul_period <= x"0000" & wdata(15 downto 0);
          elsif (reg=C_ADDR_ADC_MUX_SELECT) then
            mux_select  <= x"0000000" & "000" & wdata(0);
          elsif (reg=C_ADDR_ADC_CMP_THRESH) then
            cmp_thresh  <= x"00000" & wdata(11 downto 0);
          elsif (reg=C_ADDR_ADC_CMP_SWING) then
            cmp_swing   <= x"00000" & wdata(11 downto 0);
          elsif (reg=C_ADDR_ADC_PERIOD) then
            period      <= wdata;
          elsif (reg=C_ADDR_ADC_MODE) then
            mode        <= x"0000000" & "00" & wdata(1) & '0';
          elsif (reg=C_ADDR_ADC_TRIG) then
            trig        <= x"00000" & "0" & wdata(10 downto 8) & "000" & wdata(4 downto 0);
          elsif (reg=C_ADDR_ADC_POST) then
            post        <= wdata;
          elsif (reg=C_ADDR_ADC_ARM) then
            arm         <= '1';
          elsif (reg=C_ADDR_ADC_FORCE) then
            frc         <= '1';
          elsif (reg=C_ADDR_ADC_START) then
            start       <= '1';
          elsif (reg=C_ADDR_ADC_NEXT) then
            nxt         <= '1';
          else
            -- invalid or read-only register:  no ack
            wack <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
end;

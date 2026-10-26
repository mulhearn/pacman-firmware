library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- adc_unit:  the ADC (LTC2252, clocked by ACLK), its emulator, mux, comparator, and capture.
--
-- Captures a sample of 14 bits (data 11-0 and overflow 12 as selected by the mux,
-- comparator level 13) into a circular BRAM buffer (../bram/bram_buffer.vhd), read out over the
-- REGBUS at the logic analyzer's register offsets.  A sample every PERIOD clocks (1:  every clock;
-- 0:  none).
--
-- The trigger can be forced, self-triggered from the waveform (edge detection) or via a cross
-- trigger from the logic analyzer or (indirectly) the ATC unit.
--
-- Each sample, and the timestamp, is pipelined for four clock cycles, for consistent alignment of
-- timestamp and triggers via paths of differing latency.
--

entity adc_unit is
  generic (
    C_DEPTH_LOG2        : integer := 14      -- 16K samples
  );
  port (
    ACLK	        : in std_logic;
    RST_I	        : in std_logic;

    -- REGBUS Ports
    S_REGBUS_RB_RUPDATE : in  std_logic;
    S_REGBUS_RB_RADDR	: in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_RDATA	: out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RACK    : out std_logic;

    S_REGBUS_RB_WUPDATE : in  std_logic;
    S_REGBUS_RB_WADDR	: in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_WDATA	: in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_WACK    : out std_logic;

    -- ADC
    ADC_EN_O            : out std_logic;
    ADC_CLK_O           : out std_logic;
    ADC_DATA_I          : in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
    ADC_DOF_I           : in  std_logic;

    -- timestamp (ATC) and cross trigger (the logic analyzer)
    TIMESTAMP_I         : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    CROSS_TRIGGER_I     : in  std_logic;
    CROSS_TRIGGER_O     : out std_logic
    );
end adc_unit;

architecture behavioral of adc_unit is
  signal config    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal look      : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  signal emul_min, emul_max, emul_step, emul_period : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal mux_select, cmp_thresh, cmp_swing             : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal emul_data : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal data      : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal dof       : std_logic;
  signal level     : std_logic;

  -- capture
  constant C_SAMPLE_WIDTH : integer := ADC_DATA_WIDTH + 2;
  signal period, mode, trig, post : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal arm, frc, start, nxt     : std_logic;
  signal armed, triggered, done   : std_logic;
  signal capture_status, trig_pos, count, cap_data : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal trig_ts   : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  -- the pipeline, four clocks as la_lanes:  s1 the mux output (aligned with the comparator), s2 with
  -- the comparator, s3, s4 = the sample;  the timestamp alongside
  signal s1        : std_logic_vector(ADC_DATA_WIDTH downto 0) := (others => '0');
  signal s2, s3, s4 : std_logic_vector(C_SAMPLE_WIDTH-1 downto 0) := (others => '0');
  type ts_pipe_t is array (1 to 4) of std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal ts_p      : ts_pipe_t := (others => (others => '0'));
  signal cnt       : unsigned(31 downto 0) := (others => '0');
  signal se_r      : std_logic := '0';

begin

  look(C_RB_DATA_WIDTH-1 downto ADC_DATA_WIDTH+1) <= (others => '0');
  look(ADC_DATA_WIDTH-1 downto 0) <= data;
  look(ADC_DATA_WIDTH) <= dof;

  ADC_EN_O <= config(0);
  ADC_CLK_O <= ACLK;

  registers: entity work.adc_registers
  generic map (
    C_DEPTH             => 2**C_DEPTH_LOG2
  )
  port map (
    CLK_I               => ACLK,
    RST_I               => RST_I,
    S_REGBUS_RB_RUPDATE => S_REGBUS_RB_RUPDATE,
    S_REGBUS_RB_RADDR   => S_REGBUS_RB_RADDR,
    S_REGBUS_RB_RDATA   => S_REGBUS_RB_RDATA,
    S_REGBUS_RB_RACK    => S_REGBUS_RB_RACK,
    S_REGBUS_RB_WUPDATE => S_REGBUS_RB_WUPDATE,
    S_REGBUS_RB_WADDR   => S_REGBUS_RB_WADDR,
    S_REGBUS_RB_WDATA   => S_REGBUS_RB_WDATA,
    S_REGBUS_RB_WACK    => S_REGBUS_RB_WACK,

    CONFIG_O            => config,
    LOOK_I              => look,

    EMUL_MIN_O          => emul_min,
    EMUL_MAX_O          => emul_max,
    EMUL_STEP_O         => emul_step,
    EMUL_PERIOD_O       => emul_period,
    MUX_SELECT_O        => mux_select,
    CMP_THRESH_O        => cmp_thresh,
    CMP_SWING_O         => cmp_swing,
    CMP_LEVEL_I         => level,

    PERIOD_O            => period,
    MODE_O              => mode,
    TRIG_O              => trig,
    POST_O              => post,
    ARM_O               => arm,
    FORCE_O             => frc,
    START_O             => start,
    NEXT_O              => nxt,
    CAPTURE_STATUS_I    => capture_status,
    TRIG_POS_I          => trig_pos,
    COUNT_I             => count,
    TS_I                => trig_ts,
    DATA_I              => cap_data
  );

  emul: entity work.adc_emul port map (
    CLK_I       => ACLK,
    RST_I       => RST_I,
    ENABLE_I    => mux_select(0),
    MIN_I       => emul_min(ADC_DATA_WIDTH-1 downto 0),
    MAX_I       => emul_max(ADC_DATA_WIDTH-1 downto 0),
    STEP_I      => emul_step(ADC_DATA_WIDTH downto 0),
    PERIOD_I    => emul_period(15 downto 0),
    DATA_O      => emul_data
  );

  mux: entity work.adc_mux port map (
    SELECT_I    => mux_select(0),
    ADC_DATA_I  => ADC_DATA_I,
    ADC_DOF_I   => ADC_DOF_I,
    EMUL_DATA_I => emul_data,
    DATA_O      => data,
    DOF_O       => dof
  );

  cmp: entity work.adc_cmp port map (
    CLK_I       => ACLK,
    RST_I       => RST_I,
    DATA_I      => data,
    THRESH_I    => cmp_thresh(ADC_DATA_WIDTH-1 downto 0),
    SWING_I     => cmp_swing(ADC_DATA_WIDTH-1 downto 0),
    LEVEL_O     => level
  );

  -- capture:  the pipeline and the sample strobe (every PERIOD clocks)
  process(ACLK, RST_I)
  begin
    if (RST_I = '1') then
      s1   <= (others => '0');
      s2   <= (others => '0');
      s3   <= (others => '0');
      s4   <= (others => '0');
      ts_p <= (others => (others => '0'));
      cnt  <= (others => '0');
      se_r <= '0';
    elsif rising_edge(ACLK) then
      s1   <= dof & data;
      s2   <= level & s1;
      s3   <= s2;
      s4   <= s3;
      ts_p <= TIMESTAMP_I & ts_p(1 to 3);
      if unsigned(period) = 0 then
        cnt <= (others => '0');
      elsif cnt = 0 then
        cnt <= unsigned(period) - 1;
      else
        cnt <= cnt - 1;
      end if;
      if unsigned(period) /= 0 and cnt = 0 then
        se_r <= '1';
      else
        se_r <= '0';
      end if;
    end if;
  end process;

  capture_status <= (C_RB_DATA_WIDTH-1 downto 3 => '0') & done & triggered & armed;

  buf: entity work.bram_buffer
    generic map (
      C_DEPTH_LOG2 => C_DEPTH_LOG2,
      C_WIDTH      => C_SAMPLE_WIDTH
    )
    port map (
      CLK_I       => ACLK,
      RST_I       => RST_I,
      SAMPLE_I    => s4,
      SE_I        => se_r,
      TS_I        => ts_p(4),
      ENABLE_I    => mode(1),
      TRIG_BIT_I  => trig(4 downto 0),
      TRIG_EDGE_I => trig(9 downto 8),
      TRIG_EN_I   => trig(10),
      POST_I      => post,
      ARM_I       => arm,
      FORCE_I     => frc,
      START_I     => start,
      NEXT_I      => nxt,
      TRIG_I      => CROSS_TRIGGER_I,
      TRIG_O      => CROSS_TRIGGER_O,
      ARMED_O     => armed,
      TRIGGERED_O => triggered,
      DONE_O      => done,
      TRIG_POS_O  => trig_pos,
      COUNT_O     => count,
      TRIG_TS_O   => trig_ts,
      DATA_O      => cap_data
    );

end behavioral;

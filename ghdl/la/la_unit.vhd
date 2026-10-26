library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- la_unit:  logic analyzer unit
--
-- Samples of 32 bits into a circular BRAM buffer, read out over the REGBUS.
--
-- Inputs: the ASIC lines of every tile (PISO, POSI from the TX unit, G and H from the ATC unit),
-- and each unit's status (ATC, RX, TX; C_STATUS_BITS each).
--
-- Lanes: configurable input selection is limited to dedicated lanes (to avoid the resource costs of
-- a fully generic MUX). A sample is 8 nibbles (A-H), each one lane chosen by the final mux: four
-- tile lanes (A-D, each on a chosen tile) give PISO 0-3, POSI 0-3, and G, H in pairs; the status
-- lanes give 4 bits of a unit's status.
--
-- The trigger can be forced, self-triggered from inputs (including ATC), or via a cross trigger
-- from the ADC unit.  The ADC unit can also trigger on the trigger logic here (CROSS_TRIGGER_O)
-- even while acquisition is disabled for the logic analyzer (MODE bit 1 set to zero).
--
-- Each input, and the timestamp, is pipelined for four clock cycles, for consistent alignment of
-- timestamp and triggers via paths of differing latency.
--

entity la_unit is
  generic (
    C_DEPTH_LOG2        : integer := 15      -- 32K samples
  );
  port (
    ACLK                : in std_logic;
    RST_I               : in std_logic;

    -- REGBUS Ports
    S_REGBUS_RB_RUPDATE : in  std_logic;
    S_REGBUS_RB_RADDR   : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_RDATA   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_RACK    : out std_logic;

    S_REGBUS_RB_WUPDATE : in  std_logic;
    S_REGBUS_RB_WADDR   : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
    S_REGBUS_RB_WDATA   : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    S_REGBUS_RB_WACK    : out std_logic;

    -- inputs (ACLK domain;  PISO as synchronized by rx_unit)
    PISO_I              : in  std_logic_vector(C_NUM_UART-1 downto 0);
    POSI_I              : in  std_logic_vector(C_NUM_UART-1 downto 0);
    G_I                 : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    H_I                 : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    BAUD_I              : in  std_logic;
    ATC_STATUS_I        : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
    RX_STATUS_I         : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
    TX_STATUS_I         : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
    TIMESTAMP_I         : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);

    -- cross trigger (the ADC unit)
    CROSS_TRIGGER_I     : in  std_logic;
    CROSS_TRIGGER_O     : out std_logic
  );
end la_unit;

architecture behavioral of la_unit is
  signal tile                   : std_logic_vector(4*4-1 downto 0);
  signal mux_select             : std_logic_vector(8*5-1 downto 0);
  signal period, phase, mode    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal trig, post             : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal arm, frc, start, nxt : std_logic;
  signal armed, triggered, done : std_logic;
  signal status, trig_pos, count, data : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal trig_ts, ts            : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal sample                 : std_logic_vector(31 downto 0);
  signal se                     : std_logic;

begin

  registers: entity work.la_registers
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

      TILE_O      => tile,
      MUX_SELECT_O => mux_select,
      PERIOD_O    => period,
      PHASE_O     => phase,
      MODE_O      => mode,
      TRIG_O      => trig,
      POST_O      => post,
      ARM_O       => arm,
      FORCE_O     => frc,
      START_O     => start,
      NEXT_O      => nxt,
      STATUS_I    => status,
      TRIG_POS_I  => trig_pos,
      COUNT_I     => count,
      TS_I        => trig_ts,
      DATA_I      => data
    );

  status <= (C_RB_DATA_WIDTH-1 downto 3 => '0') & done & triggered & armed;

  lanes: entity work.la_lanes
    port map (
      CLK_I        => ACLK,
      RST_I        => RST_I,
      PISO_I       => PISO_I,
      POSI_I       => POSI_I,
      G_I          => G_I,
      H_I          => H_I,
      BAUD_I       => BAUD_I,
      ATC_STATUS_I => ATC_STATUS_I,
      RX_STATUS_I  => RX_STATUS_I,
      TX_STATUS_I  => TX_STATUS_I,
      TIMESTAMP_I  => TIMESTAMP_I,
      TILE_I       => tile,
      MUX_SELECT_I => mux_select,
      PERIOD_I     => period,
      PHASE_I      => phase,
      LOCK_I       => mode(0),
      SAMPLE_O     => sample,
      SE_O         => se,
      TS_O         => ts
    );

  buf: entity work.bram_buffer
    generic map (
      C_DEPTH_LOG2 => C_DEPTH_LOG2,
      C_WIDTH      => 32
    )
    port map (
      CLK_I       => ACLK,
      RST_I       => RST_I,
      SAMPLE_I    => sample,
      SE_I        => se,
      TS_I        => ts,
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
      DATA_O      => data
    );

end behavioral;

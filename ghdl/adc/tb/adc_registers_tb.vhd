library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;

--  Defines a testbench (without any ports)
entity adc_registers_tb is
end adc_registers_tb;

architecture behaviour of adc_registers_tb is
  component adc_registers is
    port (
      CLK_I                : in std_logic;
      RST_I                : in std_logic;

      S_REGBUS_RB_RADDR    : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_RDATA    : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RUPDATE  : in  std_logic;
      S_REGBUS_RB_RACK     : out std_logic;

      S_REGBUS_RB_WUPDATE  : in  std_logic;
      S_REGBUS_RB_WADDR    : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_WDATA    : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WACK     : out std_logic;

      CONFIG_O            : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      --STATUS_I            : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      LOOK_I              : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

      EMUL_MIN_O          : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      EMUL_MAX_O          : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      EMUL_STEP_O         : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      EMUL_PERIOD_O       : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      MUX_SELECT_O        : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CMP_THRESH_O        : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CMP_SWING_O         : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CMP_LEVEL_I         : in  std_logic;

      PERIOD_O            : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      MODE_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      TRIG_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      POST_O              : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      ARM_O               : out std_logic;
      FORCE_O             : out std_logic;
      START_O             : out std_logic;
      NEXT_O              : out std_logic;
      CAPTURE_STATUS_I    : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      TRIG_POS_I          : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      COUNT_I             : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      TS_I                : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
      DATA_I              : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
    );
  end component;
  signal count     : integer := 0;
  signal clk      : std_logic;
  signal rst   : std_logic;
  -- registers
  signal config  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');

  -- read signals:
  signal raddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal rupdate : std_logic := '0';
  signal rdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal rack    : std_logic := '0';
  -- write signals:
  signal waddr   : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal wupdate : std_logic := '0';
  signal wdata   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal wack    : std_logic := '0';
begin
  uut: adc_registers port map (
    CLK_I               => clk,
    RST_I               => rst,
    S_REGBUS_RB_RUPDATE => rupdate,
    S_REGBUS_RB_RADDR   => raddr,
    S_REGBUS_RB_RDATA   => rdata,
    S_REGBUS_RB_RACK    => rack,
    S_REGBUS_RB_WUPDATE => wupdate,
    S_REGBUS_RB_WADDR   => waddr,
    S_REGBUS_RB_WDATA   => wdata,
    S_REGBUS_RB_WACK    => wack,

    CONFIG_O            => config,
    LOOK_I              => x"00000123",

    EMUL_MIN_O          => open,
    EMUL_MAX_O          => open,
    EMUL_STEP_O         => open,
    EMUL_PERIOD_O       => open,
    MUX_SELECT_O        => open,
    CMP_THRESH_O        => open,
    CMP_SWING_O         => open,
    CMP_LEVEL_I         => '0',

    PERIOD_O            => open,
    MODE_O              => open,
    TRIG_O              => open,
    POST_O              => open,
    ARM_O               => open,
    FORCE_O             => open,
    START_O             => open,
    NEXT_O              => open,
    CAPTURE_STATUS_I    => x"00000004",
    TRIG_POS_I          => x"0000002A",
    COUNT_I             => x"00004000",
    TS_I                => x"1111111122222222",
    DATA_I              => x"00002ABC"
  );

  rst_process : process
  begin
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;

  clk_process : process
  begin
    count <= count + 1;
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  read_process : process
  begin
    wait for 1 ns;
    raddr   <= x"0000";
    rupdate <= '0';
    wait for 20 ns;
    raddr   <= x"D000";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"D004";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"D010";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"0000";
    rupdate <= '0';
    wait;
  end process;

  write_process : process
  begin
    wait for 1 ns;
    wait for 20 ns;
    waddr   <= x"D004";
    wdata   <= x"00000001";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"0000";
    wdata   <= x"00000000";
    wupdate <= '0';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    if (count < 15) then
      wait for 10 ns;
    else
      wait;
    end if;
    write (l, String'("c: "));
    write (l, count, left, 4);
    write (l, String'(" || ra: 0x"));
    hwrite (l, raddr);
    write (l, String'(" ru:"));
    write (l, rupdate);
    write (l, String'(" rd: 0x"));
    hwrite (l, rdata);
    write (l, String'(" rk:"));
    write (l, rack);
    write (l, String'(" || wa: 0x"));
    hwrite (l, waddr);
    write (l, String'(" wu:"));
    write (l, wupdate);
    write (l, String'(" wd: 0x"));
    hwrite (l, wdata);
    write (l, String'(" wk:"));
    write (l, wack);
    if (rst = '1') then
      write (l, String'(" (RESET)"));
    end if;
    writeline(output, l);
  end process;

end behaviour;


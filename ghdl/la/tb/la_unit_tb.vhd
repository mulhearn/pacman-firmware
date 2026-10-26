----------------------------------------------------------------------------------------------------
-- la_unit_tb:  logic analyzer unit test bench
--
-- One capture over the REGBUS:  configuration writes, ARM, FORCE, then the readout (START, DATA,
-- NEXT), oldest sample first.
--
-- Shows one line per clock: the REGBUS read side (ra, ru, rd, rk) | write side (wa, wu, wd, wk).
--
-- Scenario: buffer of 64;  POSI counts up, one count per clock;  lane A on tile 1, mux select A =
-- TILE_A_POSI (POSI 4-7), B = ATC_STATUS_LOWER (BAUD every 10 clocks, bit 5);  POST 4
----------------------------------------------------------------------------------------------------
library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;

entity la_unit_tb is
end la_unit_tb;

architecture behaviour of la_unit_tb is
  component la_unit is
    generic (
      C_DEPTH_LOG2        : integer := 15
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

      -- inputs
      PISO_I              : in  std_logic_vector(C_NUM_UART-1 downto 0);
      POSI_I              : in  std_logic_vector(C_NUM_UART-1 downto 0);
      G_I                 : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      H_I                 : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      BAUD_I              : in  std_logic;
      ATC_STATUS_I        : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
      RX_STATUS_I         : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
      TX_STATUS_I         : in  std_logic_vector(C_STATUS_BITS-1 downto 0);
      TIMESTAMP_I         : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);

      -- cross trigger
      CROSS_TRIGGER_I     : in  std_logic;
      CROSS_TRIGGER_O     : out std_logic
    );
  end component;

  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;

  -- regbus
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

  -- inputs
  signal posi      : std_logic_vector(C_NUM_UART-1 downto 0);
  signal baud      : std_logic;
  signal atc       : std_logic_vector(C_STATUS_BITS-1 downto 0);
  signal ts        : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);

begin
  uut: la_unit
    generic map (
      C_DEPTH_LOG2        => 6
    )
    port map (
      ACLK                => clk,
      RST_I               => rst,
      S_REGBUS_RB_RUPDATE => rupdate,
      S_REGBUS_RB_RADDR   => raddr,
      S_REGBUS_RB_RDATA   => rdata,
      S_REGBUS_RB_RACK    => rack,
      S_REGBUS_RB_WUPDATE => wupdate,
      S_REGBUS_RB_WADDR   => waddr,
      S_REGBUS_RB_WDATA   => wdata,
      S_REGBUS_RB_WACK    => wack,
      PISO_I              => (others => '0'),
      POSI_I              => posi,
      G_I                 => (others => '0'),
      H_I                 => (others => '0'),
      BAUD_I              => baud,
      ATC_STATUS_I        => atc,
      RX_STATUS_I         => (others => '0'),
      TX_STATUS_I         => (others => '0'),
      TIMESTAMP_I         => ts,
      CROSS_TRIGGER_I     => '0',
      CROSS_TRIGGER_O     => open
    );

  posi <= std_logic_vector(to_unsigned(count * 16, C_NUM_UART));     -- tile 1 (POSI 4-7):  count
  baud <= '1' when count mod 10 = 0 else '0';
  atc  <= "000000" & baud & '0';
  ts   <= std_logic_vector(to_unsigned(count, C_TIMESTAMP_WIDTH));

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

  write_process : process
  begin
    wait for 1 ns;
    wait for 20 ns;
    waddr   <= x"C080";      -- TILE_A:  tile 1
    wdata   <= x"00000001";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"C100";      -- MUX_SELECT_A:  TILE_A_POSI
    wdata   <= x"00000002";
    wait for 10 ns;
    waddr   <= x"C104";      -- MUX_SELECT_B:  ATC_STATUS_LOWER
    wdata   <= x"0000000B";
    wait for 10 ns;
    waddr   <= x"C02C";      -- TRIG:  sample bit 31 (constant 0):  FORCE only
    wdata   <= x"0000001F";
    wait for 10 ns;
    waddr   <= x"C030";      -- POST 4
    wdata   <= x"00000004";
    wait for 10 ns;
    waddr   <= x"C040";      -- ARM
    wait for 10 ns;
    waddr   <= x"0000";
    wupdate <= '0';
    wait for 100 ns;
    waddr   <= x"C044";      -- FORCE
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"0000";
    wupdate <= '0';
    wait for 100 ns;
    waddr   <= x"C048";      -- START
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"0000";
    wupdate <= '0';
    for i in 0 to 3 loop
      wait for 10 ns;
      waddr   <= x"C04C";    -- NEXT
      wupdate <= '1';
      wait for 10 ns;
      waddr   <= x"0000";
      wupdate <= '0';
      wait for 10 ns;
    end loop;
    wait;
  end process;

  read_process : process
  begin
    raddr   <= x"0000";
    rupdate <= '0';
    wait for 1 ns;
    wait for 260 ns;
    raddr   <= x"C050";      -- STATUS (done)
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"C058";      -- COUNT
    wait for 10 ns;
    raddr   <= x"C054";      -- TRIG_POS
    wait for 10 ns;
    raddr   <= x"0000";
    rupdate <= '0';
    for i in 0 to 3 loop
      wait for 10 ns;
      raddr   <= x"C070";    -- DATA
      rupdate <= '1';
      wait for 10 ns;
      raddr   <= x"0000";
      rupdate <= '0';
      wait for 10 ns;
    end loop;
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    if (count < 45) then
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

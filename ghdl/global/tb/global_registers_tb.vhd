----------------------------------------------------------------------------------------------------
-- global_registers_tb:  global register file test bench
--
-- Shows one line per register access (W writes, R reads) and output lines
-- showing how the modules output registers are driven.
--
-- Scenario: STATUS is input as fixed value 0000ABCD
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_utils.all;

entity global_registers_tb is
end global_registers_tb;

architecture behaviour of global_registers_tb is
  signal count         : integer := 0;
  signal clk           : std_logic;
  signal rst           : std_logic;
  signal rb            : rb_t := RB_IDLE;
  signal rbr           : rbr_t;
  signal analog_pwr_en : std_logic;
  signal tile_en       : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal led_config    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  -- global address:  scope (4 bits), register (12 bits)
  function glb(reg : integer) return std_logic_vector is
  begin return std_logic_vector(to_unsigned(C_SCOPE_GLOBAL * 4096 + reg, 16)); end function;
begin
  uut0: entity work.global_registers port map (
    CLK_I               => clk,
    RST_I               => rst,
    S_REGBUS_RB_RUPDATE => rb.rupdate,
    S_REGBUS_RB_RADDR   => rb.raddr,
    S_REGBUS_RB_RDATA   => rbr.rdata,
    S_REGBUS_RB_RACK    => rbr.rack,
    S_REGBUS_RB_WUPDATE => rb.wupdate,
    S_REGBUS_RB_WADDR   => rb.waddr,
    S_REGBUS_RB_WDATA   => rb.wdata,
    S_REGBUS_RB_WACK    => rbr.wack,
    ANALOG_PWR_EN_O     => analog_pwr_en,
    TILE_EN_O           => tile_en,
    GLOBAL_STATUS_I     => x"0000ABCD",
    LED_CONFIG_O        => led_config
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

  regbus_process : process
    procedure wr(reg : integer; d : std_logic_vector; txt : string) is
    begin reg_write(clk, rb, rbr, glb(reg), d, txt); wait for 2 ns; end procedure;  -- outputs first
    procedure rd(reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, glb(reg), txt); end procedure;
  begin
    wait until rst = '0';
    note("read/write registers:  after reset, written, read back");
    rd(C_ADDR_GLOBAL_SCRATCH_A, "scratch A");
    rd(C_ADDR_GLOBAL_SCRATCH_B, "scratch B");
    rd(C_ADDR_GLOBAL_ENABLES,   "enables");
    rd(C_ADDR_GLOBAL_LEDS,      "LED config");
    wr(C_ADDR_GLOBAL_SCRATCH_A, x"12345678", "scratch A");
    wr(C_ADDR_GLOBAL_SCRATCH_B, x"9ABCDEF0", "scratch B");
    wr(C_ADDR_GLOBAL_LEDS,      x"A5A5A5A5", "LED config:  all 32 bits go out");
    rd(C_ADDR_GLOBAL_SCRATCH_A, "scratch A");
    rd(C_ADDR_GLOBAL_SCRATCH_B, "scratch B");
    rd(C_ADDR_GLOBAL_LEDS,      "LED config");

    note("enables:  bit 16 analog power, bits 0-9 the tiles;  the other bits are kept, go nowhere");
    wr(C_ADDR_GLOBAL_ENABLES, x"00010000", "enables:  analog power only");
    wr(C_ADDR_GLOBAL_ENABLES, x"00000201", "enables:  tiles 0 and 9 only");
    wr(C_ADDR_GLOBAL_ENABLES, x"FFFEFC00", "enables:  every bit but the used ones");
    rd(C_ADDR_GLOBAL_ENABLES, "enables");
    wr(C_ADDR_GLOBAL_ENABLES, x"000103FF", "enables:  analog power, all tiles");

    note("read-only registers:  the status input, the firmware and hardware versions, the build"
      & " information (0 here:  filled in by the Vivado build)");
    rd(C_ADDR_GLOBAL_STATUS,         "status (input 0000ABCD)");
    rd(C_ADDR_GLOBAL_FIRMWARE_MAJOR, "firmware major");
    rd(C_ADDR_GLOBAL_FIRMWARE_MINOR, "firmware minor");
    rd(C_ADDR_GLOBAL_FIRMWARE_PATCH, "firmware patch");
    rd(C_ADDR_GLOBAL_HARDWARE_MAJOR, "hardware major");
    rd(C_ADDR_GLOBAL_HARDWARE_MINOR, "hardware minor");
    rd(C_ADDR_GLOBAL_HARDWARE_PATCH, "hardware patch");
    rd(C_ADDR_GLOBAL_SYNTHESIS_DATE, "synthesis date");
    rd(C_ADDR_GLOBAL_GIT_HASH_UPPER, "git hash, upper");
    rd(C_ADDR_GLOBAL_GIT_HASH_LOWER, "git hash, lower");
    rd(C_ADDR_GLOBAL_BUILD_FLAGS,    "build flags:  bit 0 DIRTY, bit 1 OFFICIAL_RELEASE");
    rd(C_ADDR_GLOBAL_VIVADO_MAJOR,   "Vivado major");
    rd(C_ADDR_GLOBAL_VIVADO_MINOR,   "Vivado minor");

    note("writes to read-only registers, and addresses that are not global registers");
    wr(C_ADDR_GLOBAL_STATUS,         x"FFFFFFFF", "status");
    wr(C_ADDR_GLOBAL_FIRMWARE_MAJOR, x"FFFFFFFF", "firmware major");
    rd(C_ADDR_GLOBAL_STATUS,         "status, unchanged");
    rd(C_ADDR_GLOBAL_FIRMWARE_MAJOR, "firmware major, unchanged");
    rd(16#018#, "018:  between LED config and scratch A");
    reg_read(clk, rb, rbr, x"E020", "E020:  scratch A's register, in the ATC scope");
    wait;
  end process;

  -- the outputs, whenever they change after reset (printed 2 ns later:  after the write)
  output_process : process
    variable c : integer;
  begin
    wait on analog_pwr_en, tile_en, led_config;
    c := count;
    wait for 2 ns;
    if rst = '0' then
      strip(c, "outputs:  analog power " & bits(analog_pwr_en) & " | tiles " & bits(tile_en)
        & " | LED config " & hex(led_config));
    end if;
  end process;
end behaviour;

----------------------------------------------------------------------------------------------------
-- global_unit_tb: the whole global unit, configured over the regbus.
--
-- Default scenario: scratch A and B, the enables (tile power, all tiles) and both LEDs are
-- written, then read back with STATUS and the firmware and hardware versions.  The outputs are
-- shown whenever they change.
--
-- (Alternative scenarios are in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_utils.all;

entity global_unit_tb is
end global_unit_tb;

architecture behaviour of global_unit_tb is
  signal count         : integer := 0;
  signal clk           : std_logic;
  signal rst           : std_logic;
  signal rb            : rb_t := RB_IDLE;
  signal rbr           : rbr_t;
  signal analog_pwr_en : std_logic;
  signal tile_en       : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal leds          : std_logic_vector(C_NUM_LED-1 downto 0) := (others => '0');
  -- global address:  scope (4 bits), register (12 bits)
  function glb(reg : integer) return std_logic_vector is
  begin return std_logic_vector(to_unsigned(C_SCOPE_GLOBAL * 4096 + reg, 16)); end function;
begin
  uut0: entity work.global_unit port map (
    ACLK                => clk,
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
    LED_O               => leds
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
    begin reg_write(clk, rb, rbr, glb(reg), d, txt); end procedure;
    procedure rd(reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, glb(reg), txt); end procedure;
  begin
    wait until rst = '0';
    wr(C_ADDR_GLOBAL_SCRATCH_A, x"AAAAAAAA", "scratch A");
    wr(C_ADDR_GLOBAL_SCRATCH_B, x"BBBBBBBB", "scratch B");
    wr(C_ADDR_GLOBAL_ENABLES,   x"001103FF", "enables:  analog power, all tiles");
    wr(C_ADDR_GLOBAL_LEDS,      x"00000003", "LED config:  both on");

    -- alternative settings:
    --wr(C_ADDR_GLOBAL_ENABLES,   x"00010000", "enables:  tile power only, no tiles");
    --wr(C_ADDR_GLOBAL_ENABLES,   x"00010007", "enables:  tile power, tiles 0-2");
    --wr(C_ADDR_GLOBAL_LEDS,      x"00000001", "LED config:  LED 0 only");

    rd(C_ADDR_GLOBAL_SCRATCH_A, "scratch A");
    rd(C_ADDR_GLOBAL_SCRATCH_B, "scratch B");
    rd(C_ADDR_GLOBAL_STATUS,    "status");
    rd(C_ADDR_GLOBAL_FIRMWARE_MAJOR, "firmware major");
    rd(C_ADDR_GLOBAL_FIRMWARE_MINOR, "firmware minor");
    rd(C_ADDR_GLOBAL_FIRMWARE_PATCH, "firmware patch");
    rd(C_ADDR_GLOBAL_HARDWARE_MAJOR, "hardware major");
    rd(C_ADDR_GLOBAL_HARDWARE_MINOR, "hardware minor");
    rd(C_ADDR_GLOBAL_HARDWARE_PATCH, "hardware patch");
    wait;
  end process;

  -- the outputs, whenever they change after reset
  output_process : process
  begin
    wait on analog_pwr_en, tile_en, leds;
    if rst = '0' then
      strip(count, "outputs:  analog power " & bits(analog_pwr_en) & " | tiles " & bits(tile_en) & " | leds " & bits(leds));
    end if;
  end process;
end behaviour;

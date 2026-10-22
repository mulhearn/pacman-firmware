-- global_unit_check:  unit test for the global unit (black box at the global_unit ports)
--
-- Over the REGBUS:  reset values;  scratch A/B, ENABLES and LEDS read back exactly (several patterns, no
-- crosstalk between registers);  ENABLES bit 16 drives ANALOG_PWR_EN_O (TILE_POWER_ENABLE;  ANALOG_POWER_ENABLE
-- on the schematic) and bits 9:0 TILE_EN_O (TILE_ENABLES), other bits are stored but drive nothing;  LEDS bits
-- 1:0 drive LED_O (the two board LEDs on the PL;  the other two are on MIO);  STATUS reads 0000CAFE;  the
-- version registers (firmware, hardware, synthesis date, git hash, build flags, Vivado) read the values of
-- the version packages;  read-only and undefined registers, and other scopes, get no ack and change nothing;  reads
-- and writes are acknowledged one clock after the request, also back to back;  reset clears everything.
--
-- Contracts from the RTL comments (global_registers.vhd, global_status.vhd) and register_map.vhd;
-- "current behaviour:" marks what is pinned without a stated contract, "unused:" bits with no function.
-- Stimulus changes on falling clock edges (see rx_unit_check).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.firmware_version.all;
use work.hardware_version.all;
use work.version_info_pkg.all;
use work.tb_pkg.all;

entity global_unit_check is
end global_unit_check;

architecture behaviour of global_unit_check is
  constant PERIOD : time := 10 ns;

  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal done    : boolean := false;

  signal raddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal rupdate : std_logic := '0';
  signal rdata   : std_logic_vector(31 downto 0);
  signal rack    : std_logic;
  signal waddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal wupdate : std_logic := '0';
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wack    : std_logic;

  signal analog  : std_logic;
  signal tiles   : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal leds    : std_logic_vector(C_NUM_LED-1 downto 0);

  function glb(reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_GLOBAL * 16#1000# + reg, 16));
  end function;

  function v32(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 32));
  end function;
begin
  uut: entity work.global_unit
    port map (
      ACLK => clk, RST_I => rst,
      S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata, S_REGBUS_RB_RUPDATE => rupdate,
      S_REGBUS_RB_RACK => rack, S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr,
      S_REGBUS_RB_WDATA => wdata, S_REGBUS_RB_WACK => wack,
      ANALOG_PWR_EN_O => analog, TILE_EN_O => tiles, LED_O => leds);

  clock_until(clk, done, PERIOD);

  test: process
    -- one write:  wupdate for one clock;  acked:  wack seen, latency:  clocks from the request to the ack
    procedure write_try(addr : std_logic_vector(15 downto 0); data : std_logic_vector(31 downto 0);
                        acked : out boolean; latency : out integer) is
    begin
      acked := false; latency := -1;
      wait until falling_edge(clk);
      waddr <= addr; wdata <= data; wupdate <= '1';
      wait until falling_edge(clk);
      wupdate <= '0';
      for i in 1 to 8 loop
        if wack = '1' then acked := true; latency := i; exit; end if;
        wait until falling_edge(clk);
      end loop;
    end procedure;

    procedure read_try(addr : std_logic_vector(15 downto 0); data : out std_logic_vector(31 downto 0);
                       acked : out boolean; latency : out integer) is
    begin
      acked := false; data := (others => '0'); latency := -1;
      wait until falling_edge(clk);
      raddr <= addr; rupdate <= '1';
      wait until falling_edge(clk);
      rupdate <= '0';
      for i in 1 to 8 loop
        if rack = '1' then acked := true; data := rdata; latency := i; exit; end if;
        wait until falling_edge(clk);
      end loop;
    end procedure;

    procedure write_reg(addr : std_logic_vector(15 downto 0); data : std_logic_vector(31 downto 0); msg : string) is
      variable a : boolean;
      variable l : integer;
    begin
      write_try(addr, data, a, l);
      check(a, msg & ":  write to 0x" & hex(addr) & " acknowledged");
      check_equal(l, 1, msg & ":  write ack one clock after the request");
    end procedure;

    procedure check_reg(addr : std_logic_vector(15 downto 0); expected : std_logic_vector(31 downto 0); msg : string) is
      variable v : std_logic_vector(31 downto 0);
      variable a : boolean;
      variable l : integer;
    begin
      read_try(addr, v, a, l);
      check(a, msg & ":  read of 0x" & hex(addr) & " acknowledged");
      check_equal(l, 1, msg & ":  read ack one clock after the request");
      check_equal(v, expected, msg & " (0x" & hex(addr) & ")");
    end procedure;

    procedure check_no_write(addr : std_logic_vector(15 downto 0); msg : string) is
      variable a : boolean;
      variable l : integer;
    begin
      write_try(addr, x"5A5A5A5A", a, l);
      check(not a, msg & ":  write to 0x" & hex(addr) & " not acknowledged");
    end procedure;

    procedure check_no_read(addr : std_logic_vector(15 downto 0); msg : string) is
      variable v : std_logic_vector(31 downto 0);
      variable a : boolean;
      variable l : integer;
    begin
      read_try(addr, v, a, l);
      check(not a, msg & ":  read of 0x" & hex(addr) & " not acknowledged");
    end procedure;

    procedure check_outputs(a : std_logic; t : std_logic_vector(9 downto 0); l : std_logic_vector(1 downto 0);
                            msg : string) is
    begin
      check_equal(analog, a, msg & ":  ANALOG_PWR_EN_O");
      check_equal(tiles, t, msg & ":  TILE_EN_O");
      check_equal(leds, l, msg & ":  LED_O");
    end procedure;

    type patterns_t is array (natural range <>) of std_logic_vector(31 downto 0);
    constant PATTERNS : patterns_t := (x"FFFFFFFF", x"AAAAAAAA", x"55555555", x"12345678", x"80000001", x"00000000");
    type regs_t is array (0 to 3) of integer;
    constant RW_REGS : regs_t := (C_ADDR_GLOBAL_SCRATCH_A, C_ADDR_GLOBAL_SCRATCH_B,
                                  C_ADDR_GLOBAL_ENABLES, C_ADDR_GLOBAL_LEDS);
    type ro_t is array (natural range <>) of integer;
    constant RO_REGS : ro_t := (C_ADDR_GLOBAL_STATUS, C_ADDR_GLOBAL_FIRMWARE_MAJOR, C_ADDR_GLOBAL_FIRMWARE_MINOR,
                                C_ADDR_GLOBAL_FIRMWARE_PATCH, C_ADDR_GLOBAL_HARDWARE_MAJOR, C_ADDR_GLOBAL_HARDWARE_MINOR,
                                C_ADDR_GLOBAL_HARDWARE_PATCH, C_ADDR_GLOBAL_SYNTHESIS_DATE, C_ADDR_GLOBAL_GIT_HASH_UPPER,
                                C_ADDR_GLOBAL_GIT_HASH_LOWER, C_ADDR_GLOBAL_BUILD_FLAGS, C_ADDR_GLOBAL_VIVADO_MAJOR,
                                C_ADDR_GLOBAL_VIVADO_MINOR);
    variable v : std_logic_vector(31 downto 0);
    variable seen : integer;
  begin
    wait for 3 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 2 * PERIOD;

    -- reset values
    req("REG-4.1");
    for r in RW_REGS'range loop
      check_reg(glb(RW_REGS(r)), x"00000000", "after reset");
    end loop;
    req("GLB-1.3");
    check_outputs('0', "0000000000", "00", "after reset");

    -- read/write registers:  each pattern in one register, the others keep a distinct value
    req("REG-2.1");
    for r in RW_REGS'range loop
      write_reg(glb(RW_REGS(r)), v32(16#100# + r), "distinct value");
    end loop;
    for r in RW_REGS'range loop
      for p in PATTERNS'range loop
        req("REG-2.1");
        write_reg(glb(RW_REGS(r)), PATTERNS(p), "pattern");
        check_reg(glb(RW_REGS(r)), PATTERNS(p), "read back");
        req("REG-2.2");
        for o in RW_REGS'range loop
          if o /= r then check_reg(glb(RW_REGS(o)), v32(16#100# + o), "no crosstalk"); end if;
        end loop;
      end loop;
      write_reg(glb(RW_REGS(r)), v32(16#100# + r), "distinct value again");
    end loop;

    req("GLB-1.1");
    -- ENABLES -> outputs:  bit 16 TILE_POWER_ENABLE, bits 9:0 TILE_ENABLES;  other bits stored, no effect
    write_reg(glb(C_ADDR_GLOBAL_LEDS), x"00000000", "LEDs off");
    write_reg(glb(C_ADDR_GLOBAL_ENABLES), x"00010000", "analog power only");
    check_outputs('1', "0000000000", "00", "ENABLES 00010000");
    for t in 0 to C_NUM_TILE-1 loop
      write_reg(glb(C_ADDR_GLOBAL_ENABLES), v32(2**t), "one tile");
      v := (others => '0'); v(t) := '1';
      check_outputs('0', v(9 downto 0), "00", "ENABLES tile " & integer'image(t));
    end loop;
    write_reg(glb(C_ADDR_GLOBAL_ENABLES), x"FFFEFC00", "every bit except power and tiles");
    check_outputs('0', "0000000000", "00", "unused:  ENABLES bits other than 16 and 9:0 drive nothing");
    check_reg(glb(C_ADDR_GLOBAL_ENABLES), x"FFFEFC00", "unused:  those bits are stored and read back");
    write_reg(glb(C_ADDR_GLOBAL_ENABLES), x"000103FF", "power and all tiles");
    check_outputs('1', "1111111111", "00", "ENABLES 000103FF");

    req("GLB-1.2");
    -- LEDS -> LED_O:  bits 1:0, the two PL board LEDs
    for i in 0 to 3 loop
      write_reg(glb(C_ADDR_GLOBAL_LEDS), v32(i), "LED config");
      check_equal(leds, std_logic_vector(to_unsigned(i, 2)), "LED_O follows LEDS bits 1:0 (" & integer'image(i) & ")");
    end loop;
    write_reg(glb(C_ADDR_GLOBAL_LEDS), x"FFFFFFFC", "upper LED config bits");
    check_equal(leds, "00", "unused:  LEDS bits 31:2 drive nothing");

    -- read-only registers
    req("GLB-2.1");
    check_reg(glb(C_ADDR_GLOBAL_STATUS), x"0000CAFE", "STATUS (fixed value, global_status.vhd)");
    req("GLB-2.2");
    check_reg(glb(C_ADDR_GLOBAL_FIRMWARE_MAJOR), v32(C_FIRMWARE_MAJOR), "firmware major");
    check_reg(glb(C_ADDR_GLOBAL_FIRMWARE_MINOR), v32(C_FIRMWARE_MINOR), "firmware minor");
    check_reg(glb(C_ADDR_GLOBAL_FIRMWARE_PATCH), v32(C_FIRMWARE_PATCH), "firmware patch");
    check_reg(glb(C_ADDR_GLOBAL_HARDWARE_MAJOR), v32(C_HARDWARE_MAJOR), "hardware major");
    check_reg(glb(C_ADDR_GLOBAL_HARDWARE_MINOR), v32(C_HARDWARE_MINOR), "hardware minor");
    check_reg(glb(C_ADDR_GLOBAL_HARDWARE_PATCH), v32(C_HARDWARE_PATCH), "hardware patch");
    check_reg(glb(C_ADDR_GLOBAL_SYNTHESIS_DATE), v32(C_SYNTHESIS_DATE), "synthesis date");
    check_reg(glb(C_ADDR_GLOBAL_GIT_HASH_UPPER), v32(C_GIT_HASH_UPPER), "git hash upper");
    check_reg(glb(C_ADDR_GLOBAL_GIT_HASH_LOWER), v32(C_GIT_HASH_LOWER), "git hash lower");
    check_reg(glb(C_ADDR_GLOBAL_BUILD_FLAGS),    v32(C_BUILD_FLAGS),    "build flags");
    check_reg(glb(C_ADDR_GLOBAL_VIVADO_MAJOR),   v32(C_VIVADO_MAJOR),   "Vivado major");
    check_reg(glb(C_ADDR_GLOBAL_VIVADO_MINOR),   v32(C_VIVADO_MINOR),   "Vivado minor");
    req("REG-1.2");
    for r in RO_REGS'range loop
      check_no_write(glb(RO_REGS(r)), "read-only register");
    end loop;
    check_reg(glb(C_ADDR_GLOBAL_STATUS), x"0000CAFE", "STATUS unchanged by the write attempt");
    check_reg(glb(C_ADDR_GLOBAL_FIRMWARE_MAJOR), v32(C_FIRMWARE_MAJOR), "firmware major unchanged by the write attempt");

    -- undefined registers and other scopes:  no ack, nothing changes
    write_reg(glb(C_ADDR_GLOBAL_SCRATCH_A), x"C0FFEE00", "scratch A known value");
    check_no_read (glb(16#004#), "undefined global register");
    check_no_write(glb(16#004#), "undefined global register");
    check_no_read (glb(16#FFC#), "undefined global register");
    check_no_write(std_logic_vector(to_unsigned(C_SCOPE_ATC * 16#1000# + C_ADDR_GLOBAL_SCRATCH_A, 16)), "ATC scope");
    check_no_read (std_logic_vector(to_unsigned(C_SCOPE_ATC * 16#1000# + C_ADDR_GLOBAL_SCRATCH_A, 16)), "ATC scope");
    check_no_write(x"7F20", "RX scope");
    check_no_read (x"0020", "TX scope");
    check_reg(glb(C_ADDR_GLOBAL_SCRATCH_A), x"C0FFEE00", "scratch A unchanged by the other-scope writes");

    req("REG-3.2");
    -- back-to-back reads:  one request per clock, each answered one clock later, in order
    write_reg(glb(C_ADDR_GLOBAL_SCRATCH_B), x"BBBB0002", "scratch B known value");
    wait until falling_edge(clk);
    raddr <= glb(C_ADDR_GLOBAL_SCRATCH_A); rupdate <= '1';
    wait until falling_edge(clk);
    check_equal(rack, '1', "back to back:  first read acked one clock later");
    check_equal(rdata, x"C0FFEE00", "back to back:  first read data");
    raddr <= glb(C_ADDR_GLOBAL_SCRATCH_B);
    wait until falling_edge(clk);
    check_equal(rack, '1', "back to back:  second read acked");
    check_equal(rdata, x"BBBB0002", "back to back:  second read data");
    raddr <= glb(C_ADDR_GLOBAL_STATUS);
    wait until falling_edge(clk);
    check_equal(rack, '1', "back to back:  third read acked");
    check_equal(rdata, x"0000CAFE", "back to back:  third read data");
    rupdate <= '0';
    wait until falling_edge(clk);
    check_equal(rdata, x"0000CAFE", "back to back:  last data held");
    seen := 0;
    for i in 1 to 4 loop
      wait until falling_edge(clk);
      if rack = '1' then seen := seen + 1; end if;
    end loop;
    check_equal(seen, 0, "no ack without a request");

    -- back-to-back writes
    wait until falling_edge(clk);
    waddr <= glb(C_ADDR_GLOBAL_SCRATCH_A); wdata <= x"11110001"; wupdate <= '1';
    wait until falling_edge(clk);
    check_equal(wack, '1', "back to back:  first write acked");
    waddr <= glb(C_ADDR_GLOBAL_SCRATCH_B); wdata <= x"22220002";
    wait until falling_edge(clk);
    check_equal(wack, '1', "back to back:  second write acked");
    wupdate <= '0';
    check_reg(glb(C_ADDR_GLOBAL_SCRATCH_A), x"11110001", "back to back:  first write landed");
    check_reg(glb(C_ADDR_GLOBAL_SCRATCH_B), x"22220002", "back to back:  second write landed");

    req("REG-3.3");
    -- a simultaneous read and write of the same register:  the read returns the old value
    wait until falling_edge(clk);
    raddr <= glb(C_ADDR_GLOBAL_SCRATCH_A); rupdate <= '1';
    waddr <= glb(C_ADDR_GLOBAL_SCRATCH_A); wdata <= x"33330003"; wupdate <= '1';
    wait until falling_edge(clk);
    rupdate <= '0'; wupdate <= '0';
    check_equal(rack, '1', "read during write acked");
    check_equal(wack, '1', "write during read acked");
    check_equal(rdata, x"11110001", "current behaviour:  a read in the same clock as a write returns the old value");
    check_reg(glb(C_ADDR_GLOBAL_SCRATCH_A), x"33330003", "the write landed");

    req("REG-4.1");
    -- reset clears everything
    write_reg(glb(C_ADDR_GLOBAL_ENABLES), x"000103FF", "power and all tiles");
    write_reg(glb(C_ADDR_GLOBAL_LEDS), x"00000003", "both LEDs");
    wait until falling_edge(clk);
    rst <= '1';
    wait for 2 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 2 * PERIOD;
    req("GLB-1.3");
    check_outputs('0', "0000000000", "00", "after a second reset");
    req("REG-4.1");
    for r in RW_REGS'range loop
      check_reg(glb(RW_REGS(r)), x"00000000", "after a second reset");
    end loop;

    finish("global_unit_check");
    done <= true;
    wait;
  end process;
end behaviour;

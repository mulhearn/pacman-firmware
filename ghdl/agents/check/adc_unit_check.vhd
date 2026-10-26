-- adc_unit_check:  unit test for the ADC unit (black box at the adc_unit ports)
--
-- Over the REGBUS:  STATUS, CONFIG, LOOK, the emulator, mux and comparator registers.  LOOK shows the mux's
-- choice:  the ADC pins, or the emulator's ramp (sampled by repeated LOOK reads:  values, steps, wrap-around, step
-- period, hold, restart at MIN when selected).  The comparator's hysteresis from the emulator held at chosen
-- values (PERIOD 0), thresholds clipped at both ends.  The capture:  its registers, then with the pins following a
-- free-running counter n (data = n mod 4096, overflow = bit 12 of n;  TIMESTAMP = n), so every sample says when it
-- was at the ports:  sample spacing (PERIOD), the sample and its timestamp four clocks behind the ports, FORCE,
-- wrap-around, the comparator's rising edge as the trigger (bit 13), the emulator captured, CROSS_TRIGGER_I (TRIG
-- bit 10;  timestamp one clock earlier) and CROSS_TRIGGER_O, a trigger bit beyond the sample (14-31) never
-- triggers, acquisition disabled (MODE bit 1 clear).  Buffer depth 64 (C_DEPTH_LOG2 = 6).  Contracts:  the comments
-- of adc_unit.vhd, adc_emul.vhd, adc_mux.vhd, adc_cmp.vhd, ../bram/bram_buffer.vhd and register_map.vhd.  Stimulus
-- changes on falling clock edges.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity adc_unit_check is
end adc_unit_check;

architecture behaviour of adc_unit_check is
  constant PERIOD  : time := 10 ns;

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

  signal adc_en, adc_clk : std_logic;
  constant DEPTH  : integer := 64;
  signal adc_d   : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal adc_dof : std_logic;
  signal set_d   : std_logic_vector(ADC_DATA_WIDTH-1 downto 0) := (others => '0');   -- the pins, unless follow
  signal set_dof : std_logic := '0';
  signal follow  : boolean := false;      -- the pins follow the counter n
  signal n       : unsigned(63 downto 0) := (others => '0');
  signal ts      : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal xtrig_i, xtrig_o : std_logic;
  signal xtrig_at : integer := -1;        -- CROSS_TRIGGER_I high for one clock when n = xtrig_at
  signal xo_count : integer := 0;         -- CROSS_TRIGGER_O pulses

  function adc(reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_ADC * 16#1000# + reg, 16));
  end function;

  function u32(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 32));
  end function;
begin
  uut: entity work.adc_unit
    generic map (C_DEPTH_LOG2 => 6)
    port map (
      ACLK => clk, RST_I => rst,
      S_REGBUS_RB_RUPDATE => rupdate, S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata,
      S_REGBUS_RB_RACK => rack, S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr,
      S_REGBUS_RB_WDATA => wdata, S_REGBUS_RB_WACK => wack,
      ADC_EN_O => adc_en, ADC_CLK_O => adc_clk, ADC_DATA_I => adc_d, ADC_DOF_I => adc_dof,
      TIMESTAMP_I => ts, CROSS_TRIGGER_I => xtrig_i, CROSS_TRIGGER_O => xtrig_o);

  clock_until(clk, done, PERIOD);

  stim: process(clk)
  begin
    if falling_edge(clk) then
      n <= n + 1;
    end if;
  end process;
  ts      <= std_logic_vector(n);
  adc_d   <= std_logic_vector(n(11 downto 0)) when follow else set_d;
  adc_dof <= n(12) when follow else set_dof;
  xtrig_i <= '1' when to_integer(n) = xtrig_at else '0';

  xo_monitor: process(clk)
  begin
    if rising_edge(clk) and xtrig_o = '1' then
      xo_count <= xo_count + 1;
    end if;
  end process;

  test: process
    variable v, w : std_logic_vector(31 downto 0);
    variable a    : boolean;
    variable x, y, lo, hi, nwrap : integer;
    variable ok   : boolean;
    type samples_t is array (0 to DEPTH-1) of integer;
    variable smp  : samples_t;            -- the capture in time order, 14 bits each
    variable cnt, pos, xo, t0, gap : integer;
    variable lo32 : std_logic_vector(31 downto 0);

    procedure reg_write(addr : std_logic_vector(15 downto 0); data : std_logic_vector(31 downto 0);
                        expect_ack : boolean := true) is
      variable acked : boolean := false;
    begin
      wait until falling_edge(clk);
      waddr <= addr; wdata <= data; wupdate <= '1';
      wait until falling_edge(clk);
      wupdate <= '0';
      for i in 1 to 8 loop
        wait until rising_edge(clk);
        if wack = '1' then acked := true; exit; end if;
      end loop;
      check(acked = expect_ack, "write to 0x" & hex(addr) & flag('1', " acknowledged as expected"));
    end procedure;

    procedure reg_read(addr : std_logic_vector(15 downto 0); data : out std_logic_vector(31 downto 0);
                       acked : out boolean) is
    begin
      acked := false; data := (others => '0');
      wait until falling_edge(clk);
      raddr <= addr; rupdate <= '1';
      wait until falling_edge(clk);
      rupdate <= '0';
      for i in 1 to 8 loop
        wait until rising_edge(clk);
        if rack = '1' then acked := true; data := rdata; exit; end if;
      end loop;
    end procedure;

    procedure check_reg(addr : std_logic_vector(15 downto 0); expected : std_logic_vector(31 downto 0); msg : string) is
      variable d : std_logic_vector(31 downto 0);
      variable k : boolean;
    begin
      reg_read(addr, d, k);
      check(k, msg & " (0x" & hex(addr) & ") acknowledged");
      check_equal(d, expected, msg & " (0x" & hex(addr) & ")");
    end procedure;

    function rd(addr : integer) return std_logic_vector is
    begin
      return adc(addr);
    end function;

    function look_data(d : std_logic_vector(31 downto 0)) return integer is
    begin
      return to_integer(unsigned(d(11 downto 0)));
    end function;

    -- the emulator restarts at MIN:  select the pins, then the emulator
    procedure restart is
    begin
      reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"00000000");
      reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"00000001");
    end procedure;

    -- the emulator held at value d (PERIOD 0), then the comparator level after a few clocks;  the pins at d too,
    -- so the restart through the pins shows the comparator nothing else
    procedure hold_level(d : integer; expected : std_logic; msg : string) is
      variable r : std_logic_vector(31 downto 0);
      variable k : boolean;
    begin
      wait until falling_edge(clk);
      set_d <= std_logic_vector(to_unsigned(d, ADC_DATA_WIDTH)); set_dof <= '0';
      reg_write(adc(C_ADDR_ADC_EMUL_MIN), u32(d));
      restart;
      wait for 4*PERIOD;
      reg_read(adc(C_ADDR_ADC_CMP_LEVEL), r, k);
      check(k, "CMP_LEVEL acknowledged");
      check_equal(r, (31 downto 1 => '0') & expected, msg);
    end procedure;

    procedure wait_done(msg : string; tries : integer := 400) is
      variable r : std_logic_vector(31 downto 0);
      variable k : boolean;
    begin
      for i in 1 to tries loop
        reg_read(adc(C_ADDR_ADC_CAPTURE_STATUS), r, k);
        exit when r(2) = '1';
      end loop;
      check_equal(r, x"00000004", msg & ":  capture done");
    end procedure;

    -- read the capture in time order into smp;  cnt = samples, pos = trigger position;  DATA bits 31-14 zero
    procedure read_out(msg : string) is
      variable r : std_logic_vector(31 downto 0);
      variable k, zero : boolean;
    begin
      reg_read(adc(C_ADDR_ADC_COUNT), r, k);    cnt := to_integer(unsigned(r));
      reg_read(adc(C_ADDR_ADC_TRIG_POS), r, k); pos := to_integer(unsigned(r));
      reg_write(adc(C_ADDR_ADC_START), x"00000000");
      zero := true;
      for i in 0 to cnt-1 loop
        reg_read(adc(C_ADDR_ADC_DATA), r, k);
        check(k, "DATA acknowledged");
        smp(i) := to_integer(unsigned(r(13 downto 0)));
        if r(31 downto 14) /= (31 downto 14 => '0') then zero := false; end if;
        reg_write(adc(C_ADDR_ADC_NEXT), x"00000000");
      end loop;
      check(zero, msg & ":  DATA bits 31-14 zero");
    end procedure;

    function data12(i : integer) return integer is begin return i mod 4096; end function;

    -- pins following n:  data of consecutive samples step by p (mod 4096), overflow = bit 12 of the same n
    procedure check_follow(p : integer; msg : string) is
      variable good : boolean := true;
    begin
      for i in 0 to cnt-1 loop
        if i > 0 and (data12(smp(i)) - data12(smp(i-1)) + 4096) mod 4096 /= p then good := false; end if;
      end loop;
      check(good, msg & ":  samples " & dec(p) & " clocks apart, in time order");
      good := true;
      for i in 1 to cnt-1 loop
        -- overflow = bit 12 of n:  it toggles exactly when the data wraps
        if (data12(smp(i)) < data12(smp(i-1))) /= ((smp(i) / 4096) mod 2 /= (smp(i-1) / 4096) mod 2) then
          good := false;
        end if;
      end loop;
      check(good, msg & ":  overflow (bit 12) from the same clock as the data");
    end procedure;

    procedure read_ts is
      variable k : boolean;
    begin
      reg_read(adc(C_ADDR_ADC_TS_LOWER), lo32, k);
    end procedure;

    function lo12(r : std_logic_vector(31 downto 0)) return integer is
    begin
      return to_integer(unsigned(r(11 downto 0)));
    end function;

    function lo16(r : std_logic_vector(31 downto 0)) return integer is
    begin
      return to_integer(unsigned(r(15 downto 0)));
    end function;
  begin
    wait for 3*PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 2*PERIOD;

    print("-- registers");
    check_reg(adc(C_ADDR_ADC_STATUS), x"00000ADC", "STATUS");
    reg_write(adc(C_ADDR_ADC_CONFIG), x"00000001");
    check_reg(adc(C_ADDR_ADC_CONFIG), x"00000001", "CONFIG");
    check(adc_en = '1', "CONFIG bit 0 drives ADC_EN");
    reg_write(adc(C_ADDR_ADC_EMUL_MIN), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_EMUL_MIN), x"00000FFF", "EMUL_MIN:  bits 11-0");
    reg_write(adc(C_ADDR_ADC_EMUL_MAX), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_EMUL_MAX), x"00000FFF", "EMUL_MAX:  bits 11-0");
    reg_write(adc(C_ADDR_ADC_EMUL_STEP), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_EMUL_STEP), x"00001FFF", "EMUL_STEP:  bits 12-0");
    reg_write(adc(C_ADDR_ADC_EMUL_PERIOD), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_EMUL_PERIOD), x"0000FFFF", "EMUL_PERIOD:  bits 15-0");
    reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_MUX_SELECT), x"00000001", "MUX_SELECT:  bit 0");
    reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"00000000");
    reg_write(adc(C_ADDR_ADC_CMP_THRESH), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_CMP_THRESH), x"00000FFF", "CMP_THRESH:  bits 11-0");
    reg_write(adc(C_ADDR_ADC_CMP_SWING), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_CMP_SWING), x"00000FFF", "CMP_SWING:  bits 11-0");
    reg_write(adc(C_ADDR_ADC_STATUS), x"00000000", false);      -- read only:  no ack
    reg_write(adc(C_ADDR_ADC_LOOK), x"00000000", false);
    reg_write(adc(C_ADDR_ADC_CMP_LEVEL), x"00000000", false);
    reg_read(adc(16#7F0#), v, a);
    check(not a, "undefined register:  read not acknowledged");
    reg_read(std_logic_vector(to_unsigned(C_SCOPE_LA * 16#1000# + C_ADDR_ADC_CONFIG, 16)), v, a);
    check(not a, "another scope:  not acknowledged");

    print("-- LOOK:  the ADC pins (MUX_SELECT 0)");
    wait until falling_edge(clk);
    set_d <= x"5A3"; set_dof <= '1';
    wait for 5*PERIOD;
    check_reg(adc(C_ADDR_ADC_LOOK), x"000015A3", "LOOK follows the ADC pins (DOF in bit 12)");

    print("-- emulator:  0x010 to 0x040, step 3 every 20 clocks");
    reg_write(adc(C_ADDR_ADC_EMUL_MIN), u32(16#010#));
    reg_write(adc(C_ADDR_ADC_EMUL_MAX), u32(16#040#));
    reg_write(adc(C_ADDR_ADC_EMUL_STEP), u32(3));
    reg_write(adc(C_ADDR_ADC_EMUL_PERIOD), u32(20));
    restart;
    reg_read(adc(C_ADDR_ADC_LOOK), v, a);
    check(look_data(v) = 16#010# or look_data(v) = 16#013#, "emulator starts at MIN (0x" & hex(v) & ")");
    ok := true; nwrap := 0; lo := 4095; hi := 0;
    x := look_data(v);
    for i in 1 to 300 loop
      reg_read(adc(C_ADDR_ADC_LOOK), w, a);
      y := look_data(w);
      if w(12) /= '0' or (y - 16#010#) mod 3 /= 0 or y < 16#010# or y > 16#040# then ok := false; end if;
      if y /= x and y /= x + 3 then
        if y = 16#010# and x = 16#040# then nwrap := nwrap + 1; else ok := false; end if;
      end if;
      if y < lo then lo := y; end if;
      if y > hi then hi := y; end if;
      x := y;
    end loop;
    check(ok, "emulator:  LOOK 0x010 + 3k, overflow 0, steps of 3 or 0x040 back to 0x010");
    check(lo = 16#010# and hi = 16#040# and nwrap >= 1, "emulator:  covers 0x010-0x040 and wraps (" & dec(nwrap) & " wraps)");

    print("-- emulator:  step -5 from 0x120 to 0x100 (below MIN back to MAX)");
    reg_write(adc(C_ADDR_ADC_EMUL_MIN), u32(16#100#));
    reg_write(adc(C_ADDR_ADC_EMUL_MAX), u32(16#120#));
    reg_write(adc(C_ADDR_ADC_EMUL_STEP), u32(16#2000# - 5));
    reg_write(adc(C_ADDR_ADC_EMUL_PERIOD), u32(10));
    restart;
    ok := true; nwrap := 0;
    reg_read(adc(C_ADDR_ADC_LOOK), v, a);
    x := look_data(v);
    for i in 1 to 200 loop
      reg_read(adc(C_ADDR_ADC_LOOK), w, a);
      y := look_data(w);
      if y /= x and y /= x - 5 then
        if y = 16#120# then nwrap := nwrap + 1; else ok := false; end if;
      end if;
      if y < 16#100# or y > 16#120# then ok := false; end if;
      if y /= 16#100# and (16#120# - y) mod 5 /= 0 then ok := false; end if;
      x := y;
    end loop;
    check(ok, "emulator, negative step:  steps of -5 within 0x100-0x120");
    check(nwrap >= 2, "emulator, negative step:  below MIN back to MAX (" & dec(nwrap) & " times)");

    print("-- emulator:  one step every PERIOD clocks;  PERIOD 0 holds");
    reg_write(adc(C_ADDR_ADC_EMUL_MIN), u32(0));
    reg_write(adc(C_ADDR_ADC_EMUL_MAX), u32(16#FFF#));
    reg_write(adc(C_ADDR_ADC_EMUL_STEP), u32(1));
    reg_write(adc(C_ADDR_ADC_EMUL_PERIOD), u32(50));
    restart;
    reg_read(adc(C_ADDR_ADC_LOOK), v, a);
    wait for 1000*PERIOD;
    reg_read(adc(C_ADDR_ADC_LOOK), w, a);
    x := look_data(w) - look_data(v);
    check(x >= 19 and x <= 21, "PERIOD 50:  1000 clocks later " & dec(x) & " steps (20)");
    reg_write(adc(C_ADDR_ADC_EMUL_PERIOD), u32(0));
    reg_read(adc(C_ADDR_ADC_LOOK), v, a);
    wait for 200*PERIOD;
    reg_read(adc(C_ADDR_ADC_LOOK), w, a);
    check_equal(w, v, "PERIOD 0:  the emulator holds");

    print("-- mux back to the pins");
    reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"00000000");
    check_reg(adc(C_ADDR_ADC_LOOK), x"000015A3", "MUX_SELECT 0:  LOOK the ADC pins again");

    print("-- comparator:  THRESH 0x030, SWING 4 (high from 0x034, low from 0x02C)");
    reg_write(adc(C_ADDR_ADC_CMP_THRESH), u32(16#030#));
    reg_write(adc(C_ADDR_ADC_CMP_SWING), u32(4));
    reg_write(adc(C_ADDR_ADC_EMUL_PERIOD), u32(0));
    hold_level(16#020#, '0', "0x020:  low");
    hold_level(16#033#, '0', "0x033:  stays low below THRESH + SWING");
    hold_level(16#034#, '1', "0x034:  high at THRESH + SWING");
    hold_level(16#02D#, '1', "0x02D:  stays high above THRESH - SWING");
    hold_level(16#02C#, '0', "0x02C:  low at THRESH - SWING");
    hold_level(16#030#, '0', "0x030:  stays low");

    print("-- comparator:  thresholds clipped to 0x000-0xFFF");
    reg_write(adc(C_ADDR_ADC_CMP_THRESH), u32(16#FF8#));
    reg_write(adc(C_ADDR_ADC_CMP_SWING), u32(16#010#));
    hold_level(16#FFE#, '0', "THRESH 0xFF8 + SWING 0x010 clipped to 0xFFF:  0xFFE low");
    hold_level(16#FFF#, '1', "0xFFF:  high");
    reg_write(adc(C_ADDR_ADC_CMP_THRESH), u32(16#005#));
    hold_level(16#001#, '1', "THRESH 0x005 - SWING 0x010 clipped to 0x000:  0x001 stays high");
    hold_level(16#000#, '0', "0x000:  low");

    print("-- comparator on the ADC pins");
    wait until falling_edge(clk);
    set_d <= x"5A3"; set_dof <= '1';
    reg_write(adc(C_ADDR_ADC_CMP_THRESH), u32(16#030#));
    reg_write(adc(C_ADDR_ADC_CMP_SWING), u32(4));
    reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"00000000");
    wait for 4*PERIOD;
    check_reg(adc(C_ADDR_ADC_CMP_LEVEL), x"00000001", "pins 0x5A3:  high");

    print("-- capture:  registers");
    check_reg(adc(C_ADDR_ADC_PERIOD), x"00000001", "PERIOD after reset");
    check_reg(adc(C_ADDR_ADC_MODE), x"00000002", "MODE after reset (acquisition enabled)");
    check_reg(adc(C_ADDR_ADC_DEPTH), u32(DEPTH), "DEPTH");
    check_reg(adc(C_ADDR_ADC_CAPTURE_STATUS), x"00000000", "CAPTURE_STATUS after reset (idle)");
    reg_write(adc(C_ADDR_ADC_MODE), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_MODE), x"00000002", "MODE:  bit 1");
    reg_write(adc(C_ADDR_ADC_TRIG), x"FFFFFFFF");
    check_reg(adc(C_ADDR_ADC_TRIG), x"0000071F", "TRIG:  bits 10-8, 4-0");
    reg_write(adc(C_ADDR_ADC_POST), x"12345678");
    check_reg(adc(C_ADDR_ADC_POST), x"12345678", "POST");
    reg_write(adc(C_ADDR_ADC_PERIOD), x"00000003");
    check_reg(adc(C_ADDR_ADC_PERIOD), x"00000003", "PERIOD");
    reg_write(adc(C_ADDR_ADC_PERIOD), x"00000001");
    reg_write(adc(C_ADDR_ADC_CAPTURE_STATUS), x"00000000", false);   -- read only:  no ack
    reg_write(adc(C_ADDR_ADC_COUNT), x"00000000", false);
    reg_write(adc(C_ADDR_ADC_TS_UPPER), x"00000000", false);
    reg_write(adc(C_ADDR_ADC_DATA), x"00000000", false);
    reg_read(adc(C_ADDR_ADC_ARM), v, a);
    check(not a, "ARM is write only:  read not acknowledged");
    reg_read(adc(C_ADDR_ADC_NEXT), v, a);
    check(not a, "NEXT is write only:  read not acknowledged");

    print("-- capture, pins following the counter:  every clock, FORCE, POST 10");
    follow <= true;
    reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"00000000");
    reg_write(adc(C_ADDR_ADC_TRIG), u32(31));                   -- bit 31:  beyond the sample, no edge
    reg_write(adc(C_ADDR_ADC_POST), u32(10));
    xo := xo_count;
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    wait for 20*PERIOD;
    reg_write(adc(C_ADDR_ADC_FORCE), x"00000000");
    wait_done("FORCE");
    read_out("FORCE");
    check(cnt > 10 and cnt < DEPTH, "FORCE:  " & dec(cnt) & " samples, buffer not yet full");
    check_equal(pos, cnt - 11, "FORCE:  10 samples after the triggering one");
    check_follow(1, "PERIOD 1");
    read_ts;
    check_equal(data12(smp(pos)), lo12(lo32), "FORCE:  the triggering sample's data = its timestamp (mod 4096)");
    check_equal(xo_count - xo, 1, "FORCE:  one CROSS_TRIGGER_O pulse");

    print("-- capture:  wrap-around, POST 20");
    reg_write(adc(C_ADDR_ADC_POST), u32(20));
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    wait for 200*PERIOD;
    reg_write(adc(C_ADDR_ADC_FORCE), x"00000000");
    wait_done("wrap");
    read_out("wrap");
    check_equal(cnt, DEPTH, "wrap:  buffer full");
    check_equal(pos, DEPTH - 21, "wrap:  trigger position");
    check_follow(1, "wrap");
    read_ts;
    check_equal(data12(smp(pos)), lo12(lo32), "wrap:  the triggering sample's data = its timestamp");

    print("-- capture:  PERIOD 3");
    reg_write(adc(C_ADDR_ADC_PERIOD), u32(3));
    reg_write(adc(C_ADDR_ADC_POST), u32(5));
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    wait for 60*PERIOD;
    reg_write(adc(C_ADDR_ADC_FORCE), x"00000000");
    wait_done("PERIOD 3");
    read_out("PERIOD 3");
    check_follow(3, "PERIOD 3");
    read_ts;
    gap := (data12(smp(pos)) - lo12(lo32) + 4096) mod 4096;
    check(gap < 3, "PERIOD 3:  triggering sample " & dec(gap) & " clocks after the FORCE (0-2)");
    reg_write(adc(C_ADDR_ADC_PERIOD), u32(1));

    print("-- capture:  the comparator's rising edge (bit 13), THRESH 0x800, SWING 0x10:  high from 0x810");
    reg_write(adc(C_ADDR_ADC_CMP_THRESH), u32(16#800#));
    reg_write(adc(C_ADDR_ADC_CMP_SWING), u32(16#010#));
    reg_write(adc(C_ADDR_ADC_TRIG), u32(13));
    reg_write(adc(C_ADDR_ADC_POST), u32(4));
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    wait_done("comparator", 3000);
    read_out("comparator");
    check(pos >= 1, "comparator:  a sample before the trigger");
    check_equal(data12(smp(pos)), 16#810#, "comparator:  triggering sample at THRESH + SWING");
    check(smp(pos) / 2**13 = 1 and smp(pos-1) / 2**13 = 0, "comparator:  bit 13 low then high at the trigger");
    check_equal(data12(smp(pos-1)), 16#80F#, "comparator:  level and data from the same clock (0x80F low)");
    check_equal(cnt - 1 - pos, 4, "comparator:  4 samples after");
    read_ts;
    check_equal(lo12(lo32), 16#810#, "comparator:  trigger timestamp = time of the triggering sample");

    print("-- capture:  falling edge of the comparator (bit 13), POST 0");
    reg_write(adc(C_ADDR_ADC_TRIG), u32(16#100# + 13));
    reg_write(adc(C_ADDR_ADC_POST), u32(0));
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    wait_done("comparator falling", 3000);
    read_out("comparator falling");
    check_equal(pos, cnt - 1, "comparator falling, POST 0:  the triggering sample is the last");
    check_equal(data12(smp(pos)), 16#000#, "comparator falling:  low again after the wrap (0x000 <= 0x7F0)");

    print("-- capture:  a trigger bit beyond the sample (14, 20) never triggers");
    for b in 0 to 1 loop
      reg_write(adc(C_ADDR_ADC_TRIG), u32(14 + 6*b));
      reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
      wait for 300*PERIOD;
      check_reg(adc(C_ADDR_ADC_CAPTURE_STATUS), x"00000001", "trigger bit " & dec(14 + 6*b) & ":  still armed");
    end loop;

    print("-- capture:  the emulator (MUX_SELECT 1), ramp 0x100-0x1FF, step 1 every clock");
    reg_write(adc(C_ADDR_ADC_EMUL_MIN), u32(16#100#));
    reg_write(adc(C_ADDR_ADC_EMUL_MAX), u32(16#1FF#));
    reg_write(adc(C_ADDR_ADC_EMUL_STEP), u32(1));
    reg_write(adc(C_ADDR_ADC_EMUL_PERIOD), u32(1));
    reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"00000001");
    reg_write(adc(C_ADDR_ADC_TRIG), u32(31));
    reg_write(adc(C_ADDR_ADC_POST), u32(DEPTH));
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    reg_write(adc(C_ADDR_ADC_FORCE), x"00000000");
    wait_done("emulator");
    read_out("emulator");
    ok := cnt = DEPTH;
    for i in 1 to cnt-1 loop
      x := smp(i-1); y := smp(i);
      if y >= 4096 or (y /= x + 1 and not (x = 16#1FF# and y = 16#100#)) then ok := false; end if;
    end loop;
    check(ok, "emulator:  64 samples stepping by 1 within 0x100-0x1FF, overflow 0");
    reg_write(adc(C_ADDR_ADC_MUX_SELECT), x"00000000");

    print("-- capture:  CROSS_TRIGGER_I ignored unless TRIG bit 10;  then the trigger, timestamp one clock earlier");
    reg_write(adc(C_ADDR_ADC_TRIG), u32(31));
    reg_write(adc(C_ADDR_ADC_POST), u32(6));
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    wait for 10*PERIOD;
    xtrig_at <= to_integer(n) + 5;
    wait for 30*PERIOD;
    check_reg(adc(C_ADDR_ADC_CAPTURE_STATUS), x"00000001", "CROSS_TRIGGER_I, TRIG bit 10 clear:  still armed");
    for p in 1 to 4 loop
      reg_write(adc(C_ADDR_ADC_PERIOD), u32(p));
      reg_write(adc(C_ADDR_ADC_TRIG), u32(16#400# + 31));
      xo := xo_count;
      reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
      wait for 20*PERIOD;
      t0 := to_integer(n) + 5 + p;
      xtrig_at <= t0;
      wait_done("CROSS_TRIGGER_I, PERIOD " & dec(p));
      read_out("CROSS_TRIGGER_I");
      read_ts;
      check_equal(lo16(lo32), (t0 - 5) mod 2**16, "CROSS_TRIGGER_I, PERIOD " & dec(p) &
                  ":  trigger timestamp of the clock before (4-clock pipeline)");
      gap := (data12(smp(pos)) - lo12(lo32) + 4096) mod 4096;
      check(gap >= 1 and gap <= p, "CROSS_TRIGGER_I, PERIOD " & dec(p) & ":  the triggering sample the next one (" &
            dec(gap) & " clocks later)");
      check_equal(cnt - 1 - pos, 6, "CROSS_TRIGGER_I:  POST 6");
      check_equal(xo_count - xo, 1, "CROSS_TRIGGER_I:  passed on (one CROSS_TRIGGER_O pulse)");
    end loop;
    reg_write(adc(C_ADDR_ADC_PERIOD), u32(1));

    print("-- capture:  acquisition disabled (MODE bit 1 clear):  nothing written;  edge, timestamp, POST, DONE");
    reg_write(adc(C_ADDR_ADC_MODE), x"00000000");
    reg_write(adc(C_ADDR_ADC_TRIG), u32(13));
    reg_write(adc(C_ADDR_ADC_POST), u32(3));
    xo := xo_count;
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    wait_done("acquisition disabled", 3000);
    check_reg(adc(C_ADDR_ADC_COUNT), x"00000000", "acquisition disabled:  nothing written");
    read_ts;
    check_equal(lo12(lo32), 16#810#, "acquisition disabled:  comparator edge seen, its timestamp");
    check_equal(xo_count - xo, 1, "acquisition disabled:  CROSS_TRIGGER_O pulse");
    reg_write(adc(C_ADDR_ADC_MODE), x"00000002");

    print("-- capture:  PERIOD 0, no samples");
    reg_write(adc(C_ADDR_ADC_PERIOD), u32(0));
    reg_write(adc(C_ADDR_ADC_TRIG), u32(31));
    reg_write(adc(C_ADDR_ADC_ARM), x"00000000");
    wait for 50*PERIOD;
    check_reg(adc(C_ADDR_ADC_COUNT), x"00000000", "PERIOD 0:  nothing written");
    check_reg(adc(C_ADDR_ADC_CAPTURE_STATUS), x"00000001", "PERIOD 0:  still armed");

    finish("adc_unit_check");
    done <= true;
    wait;
  end process;
end behaviour;

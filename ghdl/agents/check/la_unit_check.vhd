-- la_unit_check:  unit test for the logic analyzer unit (black box at the la_unit ports)
--
-- Over the REGBUS:  the registers, commands, lanes and captures.  Two kinds of stimulus.  Counter mode:  the inputs
-- follow one free-running counter n (POSI = n, TIMESTAMP = n, PISO 0-2, G, H, UCLK from n, BAUD when n mod 10 = 0,
-- a pulse on PISO 3 on demand), so every sample says when it was taken:  sample spacing (PERIOD), BAUD-locked
-- phase, trigger edges and position, trigger timestamp, wrap-around, readout in time order (START, NEXT, DATA),
-- and that every lane of a sample comes from the same clock.  Static mode:  fixed, distinct values on every input,
-- for the lane map (every lane, tiles in and out of range).  The capture's trigger beyond the sample edges:  FORCE
-- between sample strobes (evaluated every clock, the triggering sample the next one stored), CROSS_TRIGGER_I (TRIG
-- bit 10;  timestamp one clock earlier), one trigger per ARM, a CROSS_TRIGGER_O pulse per trigger;  acquisition
-- disabled (MODE bit 1 clear):  nothing written, the trigger and its timestamp as usual.  Buffer depth 64
-- (C_DEPTH_LOG2 = 6).  Contracts:  the comments of la_unit.vhd, la_lanes.vhd, ../bram/bram_buffer.vhd and
-- register_map.vhd.  Stimulus changes on falling clock edges.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity la_unit_check is
end la_unit_check;

architecture behaviour of la_unit_check is
  constant PERIOD  : time := 10 ns;
  constant DEPTH   : integer := 64;
  constant BAUD_P  : integer := 10;        -- BAUD strobe when n mod 10 = 0

  -- static mode values
  constant G_STATIC   : std_logic_vector(C_NUM_TILE-1 downto 0) := "1010110101";
  constant H_STATIC   : std_logic_vector(C_NUM_TILE-1 downto 0) := "0111001010";
  constant ATC_STATIC : std_logic_vector(C_STATUS_BITS-1 downto 0) := x"A5";
  constant RX_STATIC  : std_logic_vector(C_STATUS_BITS-1 downto 0) := x"C3";
  constant TX_STATIC  : std_logic_vector(C_STATUS_BITS-1 downto 0) := x"81";

  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal done    : boolean := false;
  signal static  : boolean := false;

  signal raddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal rupdate : std_logic := '0';
  signal rdata   : std_logic_vector(31 downto 0);
  signal rack    : std_logic;
  signal waddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal wupdate : std_logic := '0';
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wack    : std_logic;

  signal n       : unsigned(63 downto 0) := (others => '0');
  signal piso, posi : std_logic_vector(C_NUM_UART-1 downto 0);
  signal g, h    : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal baud    : std_logic;
  signal atc, rxs, txs : std_logic_vector(C_STATUS_BITS-1 downto 0);
  signal ts      : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal piso3   : std_logic;
  signal piso3_at : integer := -1;        -- PISO(3) goes high when n = piso3_at, low 8 later
  signal xtrig_i, xtrig_o : std_logic;
  signal xtrig_at : integer := -1;        -- CROSS_TRIGGER_I high for one clock when n = xtrig_at
  signal xo_count : integer := 0;         -- CROSS_TRIGGER_O pulses

  function la(reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_LA * 16#1000# + reg, 16));
  end function;

  function u32(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 32));
  end function;

  -- static mode:  PISO 0-3 of tile t = t+1, POSI 0-3 = 15-t
  function piso_static return std_logic_vector is
    variable v : std_logic_vector(C_NUM_UART-1 downto 0);
  begin
    for t in 0 to C_NUM_TILE-1 loop
      v(4*t+3 downto 4*t) := std_logic_vector(to_unsigned(t + 1, 4));
    end loop;
    return v;
  end function;

  function posi_static return std_logic_vector is
    variable v : std_logic_vector(C_NUM_UART-1 downto 0);
  begin
    for t in 0 to C_NUM_TILE-1 loop
      v(4*t+3 downto 4*t) := std_logic_vector(to_unsigned(15 - t, 4));
    end loop;
    return v;
  end function;

  -- the lane (0-31) expected in static mode, tile lanes A-D on tiles ta
  type tiles_t is array (0 to 3) of integer;

  function gh_static(t : integer) return std_logic_vector is
  begin
    if t < C_NUM_TILE then return H_STATIC(t) & G_STATIC(t); end if;
    return "00";
  end function;

  function lane_static(lane : integer; ta : tiles_t) return std_logic_vector is
    constant PS : std_logic_vector(C_NUM_UART-1 downto 0) := piso_static;
    constant PO : std_logic_vector(C_NUM_UART-1 downto 0) := posi_static;
    variable v  : std_logic_vector(3 downto 0) := (others => '0');
    variable t  : integer;
  begin
    if lane >= 1 and lane <= 8 then
      t := ta((lane - 1) / 2);
      if t < C_NUM_TILE then
        if lane mod 2 = 1 then v := PS(4*t+3 downto 4*t); else v := PO(4*t+3 downto 4*t); end if;
      end if;
    elsif lane = 9 then  v := gh_static(ta(1)) & gh_static(ta(0));
    elsif lane = 10 then v := gh_static(ta(3)) & gh_static(ta(2));
    elsif lane = 11 then v := ATC_STATIC(3 downto 0);
    elsif lane = 12 then v := ATC_STATIC(7 downto 4);
    elsif lane = 13 then v := RX_STATIC(3 downto 0);
    elsif lane = 14 then v := RX_STATIC(7 downto 4);
    elsif lane = 15 then v := TX_STATIC(3 downto 0);
    elsif lane = 16 then v := TX_STATIC(7 downto 4);
    end if;
    return v;
  end function;

  -- counter-mode layout (select_counter below):  bits 15-0 POSI = n, 16 UCLK = n(0), 17 BAUD, 20-22 PISO 0-2 =
  -- n(2-0), 23 PISO 3, 24 G 0 = n(0), 25 H 0 = not n(0), 26 G 1 = n(1), 27 H 1 = n(2), 31-28 zero
  function lanes_aligned(d : std_logic_vector(31 downto 0)) return boolean is
  begin
    return d(16) = d(0) and d(22 downto 20) = d(2 downto 0) and d(24) = d(0) and d(25) = not d(0) and
      d(26) = d(1) and d(27) = d(2) and d(31 downto 28) = "0000";
  end function;
begin
  uut: entity work.la_unit
    generic map (C_DEPTH_LOG2 => 6)
    port map (
      ACLK => clk, RST_I => rst,
      S_REGBUS_RB_RUPDATE => rupdate, S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata,
      S_REGBUS_RB_RACK => rack, S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr,
      S_REGBUS_RB_WDATA => wdata, S_REGBUS_RB_WACK => wack,
      PISO_I => piso, POSI_I => posi, G_I => g, H_I => h, BAUD_I => baud,
      ATC_STATUS_I => atc, RX_STATUS_I => rxs, TX_STATUS_I => txs, TIMESTAMP_I => ts,
      CROSS_TRIGGER_I => xtrig_i, CROSS_TRIGGER_O => xtrig_o);

  clock_until(clk, done, PERIOD);

  -- the inputs:  one counter, changed on falling edges (counter mode), or fixed values (static mode)
  stim: process(clk)
  begin
    if falling_edge(clk) then
      n <= n + 1;
    end if;
  end process;
  ts    <= std_logic_vector(n);
  baud  <= '0' when static else '1' when to_integer(n mod BAUD_P) = 0 else '0';
  piso3 <= '1' when piso3_at >= 0 and to_integer(n) >= piso3_at and to_integer(n) < piso3_at + 8 else '0';
  posi  <= posi_static when static else std_logic_vector(n(39 downto 0));
  piso  <= piso_static when static else (C_NUM_UART-1 downto 4 => '0') & piso3 & std_logic_vector(n(2 downto 0));
  g     <= G_STATIC when static else (C_NUM_TILE-1 downto 2 => '0') & n(1) & n(0);
  h     <= H_STATIC when static else (C_NUM_TILE-1 downto 2 => '0') & n(2) & not n(0);
  atc   <= ATC_STATIC when static else "000000" & baud & n(0);
  rxs   <= RX_STATIC when static else (others => '0');
  txs   <= TX_STATIC when static else (others => '0');
  xtrig_i <= '1' when to_integer(n) = xtrig_at else '0';

  xo_monitor: process(clk)
  begin
    if rising_edge(clk) and xtrig_o = '1' then
      xo_count <= xo_count + 1;
    end if;
  end process;

  test: process
    variable v   : std_logic_vector(31 downto 0);
    variable a   : boolean;
    variable l   : integer;
    type samples_t is array (0 to DEPTH-1) of integer;
    variable s   : samples_t;
    variable cnt, pos : integer;
    variable aligned  : boolean := true;
    variable xo, t0   : integer;
    variable lo32     : std_logic_vector(31 downto 0);
    variable ta  : tiles_t;
    type tile_sets_t is array (0 to 2) of tiles_t;
    constant TILE_SETS : tile_sets_t := ((0, 1, 2, 3), (9, 5, 10, 15), (4, 6, 8, 7));

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
      return la(addr);
    end function;

    -- lanes:  tiles 0-3 on A-D;  mux select A-H:  POSI A-D, ATC_STATUS_LOWER, TILE_A_PISO, TILE_AB_GH, ZERO
    procedure select_counter is
    begin
      for x in 0 to 3 loop
        reg_write(la(C_ADDR_LA_TILE_A + 4*x), u32(x));
        reg_write(la(C_ADDR_LA_MUX_SELECT_A + 4*x), u32(C_LA_LANE_TILE_A_POSI + 2*x));
      end loop;
      reg_write(la(C_ADDR_LA_MUX_SELECT_A + 16), u32(C_LA_LANE_ATC_STATUS_LOWER));
      reg_write(la(C_ADDR_LA_MUX_SELECT_A + 20), u32(C_LA_LANE_TILE_A_PISO));
      reg_write(la(C_ADDR_LA_MUX_SELECT_A + 24), u32(C_LA_LANE_TILE_AB_GH));
      reg_write(la(C_ADDR_LA_MUX_SELECT_A + 28), u32(C_LA_LANE_ZERO));
    end procedure;

    procedure wait_done(msg : string) is
      variable d : std_logic_vector(31 downto 0);
      variable k : boolean;
    begin
      for i in 1 to 400 loop
        reg_read(la(C_ADDR_LA_STATUS), d, k);
        exit when d(2) = '1';
      end loop;
      check_equal(d, x"00000004", msg & ":  capture done");
    end procedure;

    -- read the capture in time order into s; cnt = samples, pos = trigger position
    procedure read_out is
      variable d : std_logic_vector(31 downto 0);
      variable k : boolean;
    begin
      reg_read(la(C_ADDR_LA_COUNT), d, k);    cnt := to_integer(unsigned(d));
      reg_read(la(C_ADDR_LA_TRIG_POS), d, k); pos := to_integer(unsigned(d));
      reg_write(la(C_ADDR_LA_START), x"00000000");
      for i in 0 to cnt-1 loop
        reg_read(la(C_ADDR_LA_DATA), d, k);
        check(k, "DATA acknowledged");
        s(i) := to_integer(unsigned(d(27 downto 0)));
        if not lanes_aligned(d) then aligned := false; end if;
        reg_write(la(C_ADDR_LA_NEXT), x"00000000");
      end loop;
    end procedure;

    function nlow(x : integer) return integer is begin return x mod 2**16; end function;

    -- consecutive samples step by p (counter bits 15-0, modulo 2^16)
    procedure check_spacing(p : integer; msg : string) is
      variable ok : boolean := true;
    begin
      for i in 1 to cnt-1 loop
        if (nlow(s(i)) - nlow(s(i-1)) + 2**16) mod 2**16 /= p then ok := false; end if;
      end loop;
      check(ok, msg & ":  samples " & dec(p) & " clocks apart, in time order");
    end procedure;

    procedure check_ts(msg : string) is
      variable lo : std_logic_vector(31 downto 0);
      variable k  : boolean;
    begin
      reg_read(la(C_ADDR_LA_TS_LOWER), lo, k);
      check_equal(to_integer(unsigned(lo(15 downto 0))), nlow(s(pos)), msg & ":  trigger timestamp = time of the triggering sample");
    end procedure;

    function ts_low return integer is begin return to_integer(unsigned(lo32(15 downto 0))); end function;

    -- FORCE between strobes (PERIOD p):  the trigger timestamp is the FORCE's clock, the triggering sample the
    -- next one, 0 to p-1 clocks later
    procedure check_ts_force(p : integer; msg : string) is
      variable d : integer;
    begin
      reg_read(la(C_ADDR_LA_TS_LOWER), lo32, a);
      d := (nlow(s(pos)) - ts_low + 2**16) mod 2**16;
      check(d < p, msg & ":  triggering sample " & dec(d) & " clocks after the trigger timestamp (0-" &
            dec(p-1) & ")");
    end procedure;
  begin
    wait for 3*PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 2*PERIOD;

    print("-- registers");
    check_reg(la(C_ADDR_LA_PERIOD), x"00000001", "PERIOD after reset");
    check_reg(la(C_ADDR_LA_DEPTH), u32(DEPTH), "DEPTH");
    check_reg(la(C_ADDR_LA_STATUS), x"00000000", "STATUS after reset (idle)");
    check_reg(la(C_ADDR_LA_MODE), x"00000002", "MODE after reset (acquisition enabled)");
    reg_write(la(C_ADDR_LA_TILE_C), x"FFFFFFFF");
    check_reg(la(C_ADDR_LA_TILE_C), x"0000000F", "TILE_C:  bits 3-0");
    reg_write(la(C_ADDR_LA_MUX_SELECT_C), x"FFFFFFFF");
    check_reg(la(C_ADDR_LA_MUX_SELECT_C), x"0000001F", "MUX_SELECT_C:  bits 4-0");
    reg_write(la(C_ADDR_LA_TRIG), x"FFFFFFFF");
    check_reg(la(C_ADDR_LA_TRIG), x"0000071F", "TRIG:  bits 10-8, 4-0");
    reg_write(la(C_ADDR_LA_MODE), x"FFFFFFFF");
    check_reg(la(C_ADDR_LA_MODE), x"00000003", "MODE:  bits 1-0");
    reg_write(la(C_ADDR_LA_MODE), x"00000002");
    reg_write(la(C_ADDR_LA_STATUS), x"00000000", false);      -- read only:  no ack
    reg_write(la(C_ADDR_LA_COUNT), x"00000000", false);
    reg_write(la(C_ADDR_LA_TS_UPPER), x"00000000", false);
    reg_read(la(C_ADDR_LA_ARM), v, a);
    check(not a, "ARM is write only:  read not acknowledged");
    reg_read(la(16#7F0#), v, a);
    check(not a, "undefined register:  read not acknowledged");
    reg_read(std_logic_vector(to_unsigned(C_SCOPE_ADC * 16#1000# + C_ADDR_LA_PERIOD, 16)), v, a);
    check(not a, "another scope:  not acknowledged");

    print("-- lane map (static inputs):  every lane, tiles 0-9 and 10-15");
    static <= true;
    for t in 0 to 2 loop
      ta := TILE_SETS(t);
      for x in 0 to 3 loop
        reg_write(la(C_ADDR_LA_TILE_A + 4*x), u32(ta(x)));
      end loop;
      for grp in 0 to 3 loop
        for k in 0 to 7 loop
          reg_write(la(C_ADDR_LA_MUX_SELECT_A + 4*k), u32(8*grp + k));
        end loop;
        reg_write(la(C_ADDR_LA_TRIG), u32(31));
        reg_write(la(C_ADDR_LA_POST), u32(0));
        reg_write(la(C_ADDR_LA_ARM), x"00000000");
        wait for 5*PERIOD;
        reg_write(la(C_ADDR_LA_FORCE), x"00000000");
        wait_done("lane map");
        reg_write(la(C_ADDR_LA_START), x"00000000");
        reg_read(la(C_ADDR_LA_DATA), v, a);
        for k in 0 to 7 loop
          check_equal(v(4*k+3 downto 4*k), lane_static(8*grp + k, ta),
                      "lane " & dec(8*grp + k) & ", tiles " & dec(ta(0)) & " " & dec(ta(1)) & " " & dec(ta(2)) & " " &
                      dec(ta(3)) & " (mux select " & character'val(character'pos('A') + k) & ")");
        end loop;
      end loop;
    end loop;
    static <= false;

    select_counter;
    print("-- every clock, FORCE, POST 10 (no wrap)");
    reg_write(la(C_ADDR_LA_TRIG), u32(31));                  -- sample bit 31:  constant 0, never an edge
    reg_write(la(C_ADDR_LA_POST), u32(10));
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 20*PERIOD;
    reg_write(la(C_ADDR_LA_FORCE), x"00000000");
    wait_done("FORCE");
    read_out;
    check(cnt > 10 and cnt < DEPTH, "FORCE:  " & dec(cnt) & " samples, buffer not yet full");
    check_equal(pos, cnt - 11, "FORCE:  10 samples after the triggering one");
    check_spacing(1, "PERIOD 1");
    check_ts("FORCE");

    print("-- every clock, wrap-around, POST 20");
    reg_write(la(C_ADDR_LA_POST), u32(20));
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 200*PERIOD;
    reg_write(la(C_ADDR_LA_FORCE), x"00000000");
    wait_done("wrap");
    read_out;
    check_equal(cnt, DEPTH, "wrap:  buffer full");
    check_equal(pos, DEPTH - 21, "wrap:  trigger position");
    check_spacing(1, "wrap");
    check_ts("wrap");

    print("-- PERIOD 3 (free running)");
    reg_write(la(C_ADDR_LA_PERIOD), u32(3));
    reg_write(la(C_ADDR_LA_POST), u32(5));
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 60*PERIOD;
    reg_write(la(C_ADDR_LA_FORCE), x"00000000");
    wait_done("PERIOD 3");
    read_out;
    check_spacing(3, "PERIOD 3");

    print("-- rising edge of PISO 3 (sample bit 23), POST 4");
    reg_write(la(C_ADDR_LA_PERIOD), u32(1));
    reg_write(la(C_ADDR_LA_TRIG), u32(23));
    reg_write(la(C_ADDR_LA_POST), u32(4));
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 10*PERIOD;
    piso3_at <= to_integer(n) + 30;
    wait_done("rising edge");
    read_out;
    check(s(pos) / 2**23 mod 2 = 1 and s(pos-1) / 2**23 mod 2 = 0, "rising edge:  bit 23 low then high at the trigger");
    check_equal(nlow(s(pos)), piso3_at mod 2**16, "rising edge:  triggering sample taken when PISO 3 went high");
    check_equal(cnt - 1 - pos, 4, "rising edge:  4 samples after");
    check_ts("rising edge");

    print("-- falling edge, POST 0");
    reg_write(la(C_ADDR_LA_TRIG), u32(16#100# + 23));
    reg_write(la(C_ADDR_LA_POST), u32(0));
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 10*PERIOD;
    piso3_at <= to_integer(n) + 20;
    wait_done("falling edge");
    read_out;
    check_equal(pos, cnt - 1, "falling edge, POST 0:  the triggering sample is the last");
    check_equal(nlow(s(pos)), (piso3_at + 8) mod 2**16, "falling edge:  triggering sample taken when PISO 3 went low");
    check(s(pos) / 2**23 mod 2 = 0 and s(pos-1) / 2**23 mod 2 = 1, "falling edge:  bit 23 high then low");

    print("-- BAUD locked:  PERIOD 5, PHASE 2;  PERIOD 10, PHASE 0;  PERIOD 10, PHASE 7");
    reg_write(la(C_ADDR_LA_TRIG), u32(31));
    reg_write(la(C_ADDR_LA_MODE), x"00000003");
    for t in 0 to 2 loop
      if t = 0 then
        reg_write(la(C_ADDR_LA_PERIOD), u32(5));  reg_write(la(C_ADDR_LA_PHASE), u32(2));
      elsif t = 1 then
        reg_write(la(C_ADDR_LA_PERIOD), u32(10)); reg_write(la(C_ADDR_LA_PHASE), u32(0));
      else
        reg_write(la(C_ADDR_LA_PERIOD), u32(10)); reg_write(la(C_ADDR_LA_PHASE), u32(7));
      end if;
      reg_write(la(C_ADDR_LA_POST), u32(8));
      reg_write(la(C_ADDR_LA_ARM), x"00000000");
      wait for 300*PERIOD;
      reg_write(la(C_ADDR_LA_FORCE), x"00000000");
      wait_done("BAUD locked");
      read_out;
      if t = 0 then
        a := true;
        for i in 0 to cnt-1 loop
          if nlow(s(i)) mod 10 /= 2 and nlow(s(i)) mod 10 /= 7 then a := false; end if;
        end loop;
        check(a, "BAUD locked, PERIOD 5, PHASE 2:  every sample 2 or 7 clocks after BAUD");
        check_spacing(5, "BAUD locked, PERIOD 5");
        check(s(0) / 2**17 mod 2 = 0, "PHASE 2:  BAUD (bit 17) not in the sample");
      else
        a := true;
        for i in 0 to cnt-1 loop
          if nlow(s(i)) mod 10 /= 7*(t-1) then a := false; end if;
        end loop;
        check(a, "BAUD locked, PERIOD 10, PHASE " & dec(7*(t-1)) & ":  one sample per bit, at that phase");
        check_spacing(10, "BAUD locked, PERIOD 10");
        if t = 1 then
          check(s(0) / 2**17 mod 2 = 1, "PHASE 0:  sampled with the BAUD strobe (bit 17 set)");
        end if;
      end if;
      if t = 0 then check_ts_force(5, "BAUD locked"); else check_ts_force(10, "BAUD locked"); end if;
    end loop;
    reg_write(la(C_ADDR_LA_MODE), x"00000002");

    check(aligned, "every sample:  POSI, PISO, G, H and ATC status lanes from the same clock");

    print("-- CROSS_TRIGGER_O:  one pulse per trigger");
    check_equal(xo_count, 20, "CROSS_TRIGGER_O:  20 pulses for the 20 captures so far (12 of the lane map)");

    print("-- FORCE between sample strobes (PERIOD 4):  triggers in its clock, the triggering sample the next one");
    reg_write(la(C_ADDR_LA_TRIG), u32(31));
    reg_write(la(C_ADDR_LA_PERIOD), u32(4));
    reg_write(la(C_ADDR_LA_POST), u32(3));
    for k in 0 to 3 loop
      reg_write(la(C_ADDR_LA_ARM), x"00000000");
      wait for (40 + k)*PERIOD;
      reg_write(la(C_ADDR_LA_FORCE), x"00000000");
      wait_done("FORCE, PERIOD 4");
      read_out;
      check_ts_force(4, "FORCE, PERIOD 4 (" & dec(k) & ")");
      check_equal(cnt - 1 - pos, 3, "FORCE, PERIOD 4:  POST 3 samples after the triggering one");
      check_spacing(4, "FORCE, PERIOD 4");
    end loop;

    print("-- CROSS_TRIGGER_I:  ignored unless TRIG bit 10;  then the trigger, timestamp one clock earlier");
    reg_write(la(C_ADDR_LA_PERIOD), u32(1));
    reg_write(la(C_ADDR_LA_POST), u32(6));
    reg_write(la(C_ADDR_LA_TRIG), u32(31));
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 10*PERIOD;
    xtrig_at <= to_integer(n) + 5;
    wait for 30*PERIOD;
    check_reg(la(C_ADDR_LA_STATUS), x"00000001", "CROSS_TRIGGER_I, TRIG bit 10 clear:  still armed");
    xo := xo_count;
    reg_write(la(C_ADDR_LA_TRIG), u32(16#400# + 31));
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 10*PERIOD;
    t0 := to_integer(n) + 5;
    xtrig_at <= t0;
    wait_done("CROSS_TRIGGER_I");
    read_out;
    reg_read(la(C_ADDR_LA_TS_LOWER), lo32, a);
    check_equal(ts_low, (t0 - 5) mod 2**16, "CROSS_TRIGGER_I:  trigger timestamp of the clock before (4-clock pipeline)");
    check_equal(nlow(s(pos)), (ts_low + 1) mod 2**16, "CROSS_TRIGGER_I:  the triggering sample is the next one");
    check_equal(cnt - 1 - pos, 6, "CROSS_TRIGGER_I:  POST 6");
    check_equal(xo_count - xo, 1, "CROSS_TRIGGER_I:  passed on (one CROSS_TRIGGER_O pulse)");

    print("-- CROSS_TRIGGER_I between sample strobes (PERIOD 4, one-clock pulse at every phase):  never missed");
    reg_write(la(C_ADDR_LA_PERIOD), u32(4));
    reg_write(la(C_ADDR_LA_POST), u32(2));
    for k in 0 to 3 loop
      reg_write(la(C_ADDR_LA_ARM), x"00000000");
      wait for 20*PERIOD;
      t0 := to_integer(n) + 5 + k;
      xtrig_at <= t0;
      wait_done("CROSS_TRIGGER_I, PERIOD 4 (" & dec(k) & ")");
      read_out;
      reg_read(la(C_ADDR_LA_TS_LOWER), lo32, a);
      check_equal(ts_low, (t0 - 5) mod 2**16, "CROSS_TRIGGER_I, PERIOD 4 (" & dec(k) & "):  trigger timestamp");
      check_ts_force(5, "CROSS_TRIGGER_I, PERIOD 4 (" & dec(k) & ")");
    end loop;
    reg_write(la(C_ADDR_LA_PERIOD), u32(1));

    print("-- one trigger per ARM:  a second CROSS_TRIGGER_I, FORCE, then edges change nothing");
    reg_write(la(C_ADDR_LA_TRIG), u32(16#400# + 23));
    reg_write(la(C_ADDR_LA_POST), u32(40));
    xo := xo_count;
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 10*PERIOD;
    reg_write(la(C_ADDR_LA_FORCE), x"00000000");
    reg_read(la(C_ADDR_LA_TS_LOWER), lo32, a);
    t0 := ts_low;
    xtrig_at <= to_integer(n) + 3;
    wait for 6*PERIOD;
    reg_write(la(C_ADDR_LA_FORCE), x"00000000");
    piso3_at <= to_integer(n) + 2;
    wait_done("one trigger per ARM");
    reg_read(la(C_ADDR_LA_TS_LOWER), lo32, a);
    check_equal(ts_low, t0, "one trigger per ARM:  trigger timestamp kept");
    check_equal(xo_count - xo, 1, "one trigger per ARM:  one CROSS_TRIGGER_O pulse");
    read_out;
    check_equal(cnt - 1 - pos, 40, "one trigger per ARM:  POST from the first trigger");

    print("-- acquisition disabled (MODE bit 1 clear):  nothing written;  edges, trigger, timestamp, POST, DONE");
    reg_write(la(C_ADDR_LA_MODE), x"00000000");
    reg_write(la(C_ADDR_LA_TRIG), u32(23));
    reg_write(la(C_ADDR_LA_POST), u32(5));
    xo := xo_count;
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 10*PERIOD;
    t0 := to_integer(n) + 20;
    piso3_at <= t0;
    wait_done("acquisition disabled");
    check_reg(la(C_ADDR_LA_COUNT), x"00000000", "acquisition disabled:  nothing written");
    reg_read(la(C_ADDR_LA_TS_LOWER), lo32, a);
    check_equal(ts_low, t0 mod 2**16, "acquisition disabled:  edge seen (previous sample kept on every strobe), its timestamp");
    check_equal(xo_count - xo, 1, "acquisition disabled:  CROSS_TRIGGER_O pulse");
    reg_write(la(C_ADDR_LA_MODE), x"00000002");

    print("-- PERIOD 0:  no samples");
    reg_write(la(C_ADDR_LA_PERIOD), u32(0));
    reg_write(la(C_ADDR_LA_ARM), x"00000000");
    wait for 50*PERIOD;
    check_reg(la(C_ADDR_LA_COUNT), x"00000000", "PERIOD 0:  nothing written");
    check_reg(la(C_ADDR_LA_STATUS), x"00000001", "PERIOD 0:  still armed");

    finish("la_unit_check");
    done <= true;
    wait;
  end process;
end behaviour;

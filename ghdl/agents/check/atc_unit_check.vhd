-- atc_unit_check:  unit test for the timing unit (black box at the atc_unit ports)
--
-- Over the REGBUS: configures the UART/BAUD timers, the stimulus routing
-- (DST_* registers: bit 0 -> G, bit 1 -> H, bits 2-5 -> markers M0-M3,
-- bits 6-15 -> tiles, bits 31-16 -> G/H pulse length in clock cycles), the
-- output buffers (CONFIG_G/H: phase in bits 7:0, per-tile inversion in bits
-- 17:8), and fires pokes; drives the LEMO inputs.  Checks BAUD_O, UCLK_O,
-- TIMESTAMP_O (and its reset by marker 0), G_O/H_O pulses per tile,
-- RX_MARKER_O, LEMO edge detection with debounce and inversion, and the
-- request-driven counters (COUNT_REQ / COUNT).
--
-- Contracts come from the RTL comments (atc_counter.vhd command table) and
-- the RTL itself (the ATC is not documented in the TRM yet); "current
-- behaviour:" marks what is pinned without a stated contract.  Stimulus
-- changes on falling clock edges (see rx_unit_check).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity atc_unit_check is
end atc_unit_check;

architecture behaviour of atc_unit_check is
  constant PERIOD : time := 10 ns;

  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal done    : boolean := false;
  signal cycle   : integer := 0;

  signal raddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal rupdate : std_logic := '0';
  signal rdata   : std_logic_vector(31 downto 0);
  signal rack    : std_logic;
  signal waddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal wupdate : std_logic := '0';
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wack    : std_logic;

  signal lemo_a, lemo_b : std_logic := '0';
  signal baud    : std_logic;
  signal ts      : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal marker  : std_logic_vector(C_NUM_MARKER-1 downto 0);
  signal uclk    : std_logic;
  signal g, h    : std_logic_vector(C_NUM_TILE-1 downto 0);

  -- output monitors: rising edges and cycles high since the last clear
  type tile_count_t is array (0 to C_NUM_TILE-1) of integer;
  type marker_count_t is array (0 to C_NUM_MARKER-1) of integer;
  signal g_edges, g_high, h_edges, h_high : tile_count_t := (others => 0);
  signal m_pulses : marker_count_t := (others => 0);
  signal g_first  : tile_count_t := (others => -1);   -- cycle of the first rising edge
  signal clear_mon : boolean := false;
  signal baud_last, uclk_rise_last : integer := -1;
  signal baud_period, uclk_period, uclk_high_len : integer := -1;

  function atc(reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_ATC * 16#1000# + reg, 16));
  end function;

  -- DST register value: route to g/h, markers, tiles, pulse length
  function dst(to_g, to_h : boolean; markers : std_logic_vector(3 downto 0);
               tiles : std_logic_vector(9 downto 0); len : integer) return std_logic_vector is
    variable v : std_logic_vector(31 downto 0) := (others => '0');
  begin
    if to_g then v(0) := '1'; end if;
    if to_h then v(1) := '1'; end if;
    v(5 downto 2)   := markers;
    v(15 downto 6)  := tiles;
    v(31 downto 16) := std_logic_vector(to_unsigned(len, 16));
    return v;
  end function;
begin
  uut: entity work.atc_unit
    port map (
      ACLK => clk, RST_I => rst,
      S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata, S_REGBUS_RB_RUPDATE => rupdate,
      S_REGBUS_RB_RACK => rack, S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr,
      S_REGBUS_RB_WDATA => wdata, S_REGBUS_RB_WACK => wack,
      LEMO_A_I => lemo_a, LEMO_B_I => lemo_b,
      BAUD_O => baud, TIMESTAMP_O => ts, RX_MARKER_O => marker, UCLK_O => uclk,
      G_O => g, H_O => h);

  clock_until(clk, done, PERIOD);

  monitor: process(clk)
    variable g_prev, h_prev : std_logic_vector(C_NUM_TILE-1 downto 0) := (others => '0');
    variable uclk_prev : std_logic := '0';
  begin
    if rising_edge(clk) then
      cycle <= cycle + 1;
      if clear_mon then
        g_edges <= (others => 0); g_high <= (others => 0);
        h_edges <= (others => 0); h_high <= (others => 0);
        m_pulses <= (others => 0); g_first <= (others => -1);
      else
        for i in 0 to C_NUM_TILE-1 loop
          if g(i) = '1' and g_prev(i) = '0' then
            g_edges(i) <= g_edges(i) + 1;
            if g_first(i) < 0 then g_first(i) <= cycle; end if;
          end if;
          if g(i) = '1' then g_high(i) <= g_high(i) + 1; end if;
          if h(i) = '1' and h_prev(i) = '0' then h_edges(i) <= h_edges(i) + 1; end if;
          if h(i) = '1' then h_high(i) <= h_high(i) + 1; end if;
        end loop;
        for i in 0 to C_NUM_MARKER-1 loop
          if marker(i) = '1' then m_pulses(i) <= m_pulses(i) + 1; end if;
        end loop;
      end if;
      g_prev := g;
      h_prev := h;
      if baud = '1' then
        if baud_last >= 0 then baud_period <= cycle - baud_last; end if;
        baud_last <= cycle;
      end if;
      if uclk = '1' and uclk_prev = '0' then
        if uclk_rise_last >= 0 then uclk_period <= cycle - uclk_rise_last; end if;
        uclk_rise_last <= cycle;
      end if;
      if uclk = '0' and uclk_prev = '1' then
        uclk_high_len <= cycle - uclk_rise_last;
      end if;
      uclk_prev := uclk;
    end if;
  end process;

  test: process
    procedure reg_write(addr : std_logic_vector(15 downto 0); data : std_logic_vector(31 downto 0)) is
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
      check(acked, "write to 0x" & hex(addr) & " acknowledged");
    end procedure;

    procedure reg_read(addr : std_logic_vector(15 downto 0); data : out std_logic_vector(31 downto 0);
                       acked : out boolean; latency : out integer) is
    begin
      acked := false; data := (others => '0'); latency := -1;
      wait until falling_edge(clk);
      raddr <= addr; rupdate <= '1';
      wait until falling_edge(clk);
      rupdate <= '0';
      for i in 1 to 8 loop
        wait until rising_edge(clk);
        if rack = '1' then acked := true; data := rdata; latency := i; exit; end if;
      end loop;
    end procedure;

    procedure check_reg(addr : std_logic_vector(15 downto 0); expected : std_logic_vector(31 downto 0); msg : string) is
      variable v : std_logic_vector(31 downto 0);
      variable a : boolean;
      variable l : integer;
    begin
      reg_read(addr, v, a, l);
      check(a, msg & " (0x" & hex(addr) & ") acknowledged");
      check_equal(v, expected, msg & " (0x" & hex(addr) & ")");
    end procedure;

    -- request-driven counters: command byte, then read COUNT
    procedure count_cmd(cmd : integer) is
    begin
      reg_write(atc(C_ADDR_ATC_COUNT_REQ), std_logic_vector(to_unsigned(cmd, 32)));
    end procedure;
    procedure read_count(cmd : integer; edges : out integer; integral : out integer) is
      variable v : std_logic_vector(31 downto 0);
      variable a : boolean;
      variable l : integer;
    begin
      wait for 100 ns;                  -- counters are pipelined
      count_cmd(cmd);
      wait for 30 ns;
      reg_read(atc(C_ADDR_ATC_COUNT), v, a, l);
      check(a, "COUNT acknowledged");
      edges := to_integer(unsigned(v(15 downto 0)));
      integral := to_integer(unsigned(v(31 downto 16)));
    end procedure;

    procedure clear_monitors is
    begin
      wait until falling_edge(clk);
      clear_mon <= true;
      wait until falling_edge(clk);
      clear_mon <= false;
    end procedure;

    procedure pulse_lemo_b(high : time) is
    begin
      wait until falling_edge(clk);
      lemo_b <= '1';
      wait for high;
      lemo_b <= '0';
    end procedure;

    -- the H pulses of one stimulus:  only tiles 0 and 2, once each;  G and the other tiles quiet
    procedure check_h_tiles_0_2(src : string) is
    begin
      for i in 0 to C_NUM_TILE-1 loop
        if i = 0 or i = 2 then
          check_equal(h_edges(i), 1, src & ":  H tile " & integer'image(i) & " pulses once");
        else
          check_equal(h_edges(i), 0, src & ":  H tile " & integer'image(i) & " quiet");
        end if;
        check_equal(g_edges(i), 0, src & ":  G tile " & integer'image(i) & " quiet");
      end loop;
    end procedure;

    procedure pulse_lemo_a(high : time) is
    begin
      wait until falling_edge(clk);
      lemo_a <= '1';
      wait for high;
      lemo_a <= '0';
    end procedure;

    variable v   : std_logic_vector(31 downto 0);
    variable ok  : boolean;
    variable lat : integer;
    variable e, n : integer;
    variable t1, t2 : integer;
  begin
    rst <= '1';
    wait for 10 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 50 * PERIOD;

    ---------------------------------------------------------------------
    print("-- register defaults and REGBUS behaviour");
    req("REG-4.1");
    check_reg(atc(C_ADDR_ATC_STATUS), x"00000000", "STATUS reads 0 (no status bits defined)");
    check_reg(atc(C_ADDR_ATC_CONFIG_UART),  x"0000000A", "CONFIG_UART default");
    check_reg(atc(C_ADDR_ATC_CONFIG_BAUD),  x"0000000A", "CONFIG_BAUD default");
    check_reg(atc(C_ADDR_ATC_CONFIG_INPUT), x"00000000", "CONFIG_INPUT default");
    check_reg(atc(C_ADDR_ATC_CONFIG_G),     x"00000000", "CONFIG_G default");
    check_reg(atc(C_ADDR_ATC_CONFIG_H),     x"00000000", "CONFIG_H default");
    check_reg(atc(C_ADDR_ATC_DST_LEMO_A),   x"00000000", "DST_LEMO_A default");
    check_reg(atc(C_ADDR_ATC_DST_POKE_D),   x"00000000", "DST_POKE_D default");
    req("REG-3.1");
    reg_read(atc(C_ADDR_ATC_CONFIG_UART), v, ok, lat);
    -- current behaviour: the ATC answers one cycle after the request (RX/TX: two)
    check_equal(lat, 1, "read acknowledge latency");
    req("REG-1.2");
    reg_read(atc(16#FFC#), v, ok, lat);
    check(not ok, "undefined ATC register: no read acknowledge");
    reg_read(atc(C_ADDR_ATC_POKE_A), v, ok, lat);
    check(not ok, "POKE registers are write only: no read acknowledge");
    reg_read(x"F020", v, ok, lat);
    check(not ok, "other scope: no read acknowledge from ATC");
    req("REG-2.1");
    reg_write(atc(C_ADDR_ATC_DST_LOGIC_B), x"12345678");
    check_reg(atc(C_ADDR_ATC_DST_LOGIC_B), x"12345678", "DST_LOGIC_B read back");
    reg_write(atc(C_ADDR_ATC_DST_LOGIC_B), x"00000000");

    ---------------------------------------------------------------------
    print("-- BAUD_O, UCLK_O and the timestamp follow CONFIG_BAUD / CONFIG_UART");
    req("ATC-1.1");
    wait for 1 us;
    check_equal(baud_period, 10, "BAUD_O period (cycles), default");
    check_equal(uclk_period, 10, "UCLK_O period (cycles), default");
    check_equal(uclk_high_len, 5, "UCLK_O high for half the period");
    t1 := to_integer(unsigned(ts(30 downto 0)));
    wait for 1 us;
    t2 := to_integer(unsigned(ts(30 downto 0)));
    req("ATC-1.2");
    check_equal(t2 - t1, 10, "TIMESTAMP_O counts UART periods (10 per 1 us at 10 cycles)");
    reg_read(atc(C_ADDR_ATC_TIMESTAMP), v, ok, lat);
    check(ok and abs(to_integer(unsigned(v(30 downto 0))) - to_integer(unsigned(ts(30 downto 0)))) <= 1,
          "TIMESTAMP register = TIMESTAMP_O (low 32 bits)");
    reg_write(atc(C_ADDR_ATC_CONFIG_BAUD), x"00000014");
    reg_write(atc(C_ADDR_ATC_CONFIG_UART), x"00000020");
    wait for 2 us;
    req("ATC-1.1");
    check_equal(baud_period, 20, "BAUD_O period with CONFIG_BAUD = 20");
    check_equal(uclk_period, 32, "UCLK_O period with CONFIG_UART = 32");
    check_equal(uclk_high_len, 16, "UCLK_O high half with CONFIG_UART = 32");
    t1 := to_integer(unsigned(ts(30 downto 0)));
    wait for 3200 ns;
    t2 := to_integer(unsigned(ts(30 downto 0)));
    req("ATC-1.2");
    check_equal(t2 - t1, 10, "TIMESTAMP_O counts UART periods (32 cycles)");
    reg_write(atc(C_ADDR_ATC_CONFIG_BAUD), x"0000000A");
    reg_write(atc(C_ADDR_ATC_CONFIG_UART), x"0000000A");
    wait for 1 us;

    ---------------------------------------------------------------------
    print("-- poke A routed to G on tiles 0-4, masked by the poke data to tiles 1 and 3");
    req("ATC-2.1");
    reg_write(atc(C_ADDR_ATC_DST_POKE_A), dst(true, false, "0000", "0000011111", 200));
    clear_monitors;
    reg_write(atc(C_ADDR_ATC_POKE_A), x"0000000A");      -- tiles 1 and 3
    wait for 4 us;
    for i in 0 to C_NUM_TILE-1 loop
      if i = 1 or i = 3 then
        check_equal(g_edges(i), 1, "G tile " & integer'image(i) & " pulses once");
        -- G_O moves on the UART period grid, so the length is within one period of 200
        check(abs(g_high(i) - 200) <= 10, "G tile " & integer'image(i) & " high " & integer'image(g_high(i)) & " cycles (200)");
      else
        check_equal(g_edges(i), 0, "G tile " & integer'image(i) & " quiet");
      end if;
      check_equal(h_edges(i), 0, "H tile " & integer'image(i) & " quiet");
    end loop;
    check_equal(g_first(3), g_first(1), "tiles 1 and 3 together");

    print("-- poke B routed to H and G with markers 1 and 3");
    req("ATC-2.1");
    reg_write(atc(C_ADDR_ATC_DST_POKE_B), dst(true, true, "1010", "1111111111", 50));
    clear_monitors;
    reg_write(atc(C_ADDR_ATC_POKE_B), x"000003FF");
    wait for 2 us;
    for i in 0 to C_NUM_TILE-1 loop
      check_equal(g_edges(i), 1, "poke B: G tile " & integer'image(i));
      check_equal(h_edges(i), 1, "poke B: H tile " & integer'image(i));
    end loop;
    req("ATC-2.2");
    check_equal(m_pulses(1), 1, "poke B: marker 1 pulse");
    check_equal(m_pulses(3), 1, "poke B: marker 3 pulse");
    check_equal(m_pulses(0) + m_pulses(2), 0, "poke B: markers 0 and 2 quiet");

    print("-- CONFIG_G phase moves G within the UART period; inversion bits invert per tile");
    req("ATC-3.1");
    reg_write(atc(C_ADDR_ATC_CONFIG_G), x"00000000");
    clear_monitors;
    reg_write(atc(C_ADDR_ATC_POKE_B), x"00000001");
    wait for 2 us;
    t1 := g_first(0);
    reg_write(atc(C_ADDR_ATC_CONFIG_G), x"00000005");
    clear_monitors;
    reg_write(atc(C_ADDR_ATC_POKE_B), x"00000001");
    wait for 2 us;
    t2 := g_first(0);
    check_equal((t2 - t1) mod 10, 5, "phase 5 moves G 5 cycles later within the period");
    reg_write(atc(C_ADDR_ATC_CONFIG_G), x"00000300");   -- invert tiles 0 and 1
    wait for 1 us;
    check_equal(g, "0000000011", "inverted tiles idle high");
    reg_write(atc(C_ADDR_ATC_CONFIG_G), x"00000000");
    wait for 1 us;
    check_equal(g, "0000000000", "G idle low");

    print("-- marker 0 restarts the timestamp");
    req("ATC-1.3");
    reg_write(atc(C_ADDR_ATC_DST_POKE_C), dst(false, false, "0001", "0000000000", 0));
    wait for 1 us;
    check(to_integer(unsigned(ts(30 downto 0))) > 100, "timestamp running before the restart");
    clear_monitors;
    reg_write(atc(C_ADDR_ATC_POKE_C), x"00000000");
    wait for 300 ns;                              -- TIMESTAMP_O lags two UART periods
    check_equal(m_pulses(0), 1, "marker 0 pulse");
    check(to_integer(unsigned(ts(30 downto 0))) <= 12, "timestamp restarted near 0 (" & integer'image(to_integer(unsigned(ts(30 downto 0)))) & ")");

    ---------------------------------------------------------------------
    print("-- LEMO A: rising edges (held 2+ cycles) become stimuli; glitches and bounces do not");
    req("ATC-4.1");
    reg_write(atc(C_ADDR_ATC_DST_LEMO_A), dst(true, false, "0100", "0000000001", 30));
    clear_monitors;
    pulse_lemo_a(100 ns);
    wait for 1 us;
    check_equal(m_pulses(2), 1, "LEMO A edge: marker 2");
    check_equal(g_edges(0), 1, "LEMO A edge: G tile 0");
    clear_monitors;
    pulse_lemo_a(10 ns);                          -- one cycle: filtered
    wait for 1 us;
    check_equal(m_pulses(2), 0, "one-cycle LEMO glitch ignored");
    clear_monitors;
    pulse_lemo_a(20 ns);                          -- bounce: high, low, high within the 4-cycle debounce
    wait for 10 ns;
    lemo_a <= '1';
    wait for 100 ns;
    lemo_a <= '0';
    wait for 1 us;
    check_equal(m_pulses(2), 1, "bouncing LEMO edge counted once");
    clear_monitors;
    reg_write(atc(C_ADDR_ATC_CONFIG_INPUT), x"00000001");   -- invert LEMO A
    wait for 200 ns;
    clear_monitors;
    pulse_lemo_a(500 ns);                          -- the falling edge is now the stimulus
    wait for 200 ns;
    check_equal(m_pulses(2), 1, "inverted LEMO A: falling edge counts");
    reg_write(atc(C_ADDR_ATC_CONFIG_INPUT), x"00000000");
    wait for 200 ns;

    ---------------------------------------------------------------------
    print("-- counters (COUNT_REQ commands, atc_counter.vhd)");
    req("ATC-5.1");
    count_cmd(16#10#);                             -- CLEAR
    for k in 1 to 3 loop
      pulse_lemo_a(100 ns);
      wait for 500 ns;                             -- longer than the 30-cycle G pulse
    end loop;
    reg_write(atc(C_ADDR_ATC_POKE_A), x"00000002");
    wait for 3 us;
    read_count(16#70#, e, n);                      -- READ I 0: LEMO A
    check_equal(e, 3, "LEMO A edge count");
    read_count(16#72#, e, n);                      -- READ I 2: poke A
    check_equal(e, 1, "poke A count");
    read_count(16#51#, e, n);                      -- READ G 1
    check_equal(e, 1, "G tile 1 pulse count");
    check(abs(n - 200) <= 2, "G tile 1 integral " & integer'image(n) & " cycles (200)");
    read_count(16#50#, e, n);                      -- READ G 0 (LEMO A x3)
    check_equal(e, 3, "G tile 0 pulse count");
    read_count(16#42#, e, n);                      -- READ M 2
    check_equal(e, 3, "marker 2 count");
    count_cmd(16#30#);                             -- STOP
    pulse_lemo_a(100 ns);
    wait for 300 ns;
    read_count(16#70#, e, n);
    check_equal(e, 3, "stopped: LEMO A count unchanged");
    count_cmd(16#20#);                             -- START
    pulse_lemo_a(100 ns);
    wait for 300 ns;
    read_count(16#70#, e, n);
    check_equal(e, 4, "started: LEMO A counts again");
    count_cmd(16#10#);
    read_count(16#70#, e, n);
    check_equal(e, 0, "CLEAR zeroes the counts");

    print("-- the other sources route by their DST registers too:  LEMO B, POKE C, POKE D to H on tiles 0 and 2");
    req("ATC-2.3");
    reg_write(atc(C_ADDR_ATC_CONFIG_INPUT), x"00000000");
    reg_write(atc(C_ADDR_ATC_DST_LEMO_B), dst(false, true, "0000", "0000000101", 20));
    clear_monitors;
    pulse_lemo_b(100 ns);
    wait for 1 us;
    check_h_tiles_0_2("LEMO B");
    reg_write(atc(C_ADDR_ATC_DST_LEMO_B), x"00000000");
    reg_write(atc(C_ADDR_ATC_DST_POKE_C), dst(false, true, "0000", "1111111111", 20));
    clear_monitors;
    reg_write(atc(C_ADDR_ATC_POKE_C), x"00000005");      -- the poke data masks the tiles:  0 and 2
    wait for 1 us;
    check_h_tiles_0_2("POKE C");
    reg_write(atc(C_ADDR_ATC_DST_POKE_C), x"00000000");
    reg_write(atc(C_ADDR_ATC_DST_POKE_D), dst(false, true, "0000", "1111111111", 20));
    clear_monitors;
    reg_write(atc(C_ADDR_ATC_POKE_D), x"00000005");
    wait for 1 us;
    check_h_tiles_0_2("POKE D");
    reg_write(atc(C_ADDR_ATC_DST_POKE_D), x"00000000");

    print("-- LOGIC A and B:  off by design for now:  atc_unit hard-codes their timers to CONFIG 0, so they never fire");
    req("ATC-2.4");
    reg_write(atc(C_ADDR_ATC_DST_LOGIC_A), dst(true, true, "1111", "1111111111", 20));
    reg_write(atc(C_ADDR_ATC_DST_LOGIC_B), dst(true, true, "1111", "1111111111", 20));
    clear_monitors;
    wait for 3 us;
    for i in 0 to C_NUM_TILE-1 loop
      check_equal(g_edges(i) + h_edges(i), 0, "LOGIC A/B routed everywhere:  tile " & integer'image(i) & " quiet");
    end loop;
    for i in 0 to C_NUM_MARKER-1 loop
      check_equal(m_pulses(i), 0, "LOGIC A/B routed everywhere:  marker " & integer'image(i) & " quiet");
    end loop;
    reg_write(atc(C_ADDR_ATC_DST_LOGIC_A), x"00000000");
    reg_write(atc(C_ADDR_ATC_DST_LOGIC_B), x"00000000");

    print("-- reset restores the defaults");
    req("REG-4.1");
    reg_write(atc(C_ADDR_ATC_CONFIG_UART), x"00000040");
    wait until falling_edge(clk);
    rst <= '1';
    wait for 5 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 5 * PERIOD;
    check_reg(atc(C_ADDR_ATC_CONFIG_UART), x"0000000A", "CONFIG_UART after reset");
    check_reg(atc(C_ADDR_ATC_DST_POKE_A), x"00000000", "DST_POKE_A after reset");

    finish("atc_unit_check");
    done <= true;
    wait;
  end process;
end behaviour;

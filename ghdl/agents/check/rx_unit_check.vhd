-- rx_unit_check:  unit test for the RX unit (black box at the rx_unit ports)
--
-- Configures the unit over the REGBUS, drives LArPix-style UART frames
-- (start bit, 64 data bits LSB first, stop bit, 100 ns per bit) into
-- PISO, and checks what comes out of the AXI stream:  per word a header
-- fragment, a timestamp fragment and a data fragment, and per packet a
-- trailer (EOP header, word count, LAST).  Also checks register defaults,
-- the per-channel counters, and the options (mode, input select, word type
-- LUT, PACMAN id, channel ids, packet size, timeout, sync words, markers,
-- the pattern generator, the look registers).
--
-- Contracts come from the RTL comments (rx_buffer.vhd, rx_chan.vhd,
-- rx_header.vhd, rx_registers.vhd, register_map.vhd, common.vhd).  Where
-- they were ambiguous the test pins down current behaviour and says so
-- ("current behaviour:").
--
-- Stimulus changes on falling clock edges: the DUT copies its clock through
-- a few signal assignments (clk <= CLK_I), so its rising edges come some
-- delta cycles after the testbench's, and anything assigned at the
-- testbench's rising edge would already be seen by the DUT at that edge.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity rx_unit_check is
end rx_unit_check;

architecture behaviour of rx_unit_check is
  component rx_unit is
    port (
      ACLK                : in std_logic;
      RST_I               : in std_logic;
      BAUD_I              : in std_logic;
      M_AXIS_TDATA        : out std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0);
      M_AXIS_TVALID       : out std_logic;
      M_AXIS_TREADY       : in std_logic;
      M_AXIS_TKEEP        : out std_logic_vector(C_RX_AXIS_WIDTH/8-1 downto 0);
      M_AXIS_TLAST        : out std_logic;
      S_REGBUS_RB_RADDR   : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_RDATA   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RUPDATE : in  std_logic;
      S_REGBUS_RB_RACK    : out std_logic;
      S_REGBUS_RB_WUPDATE : in  std_logic;
      S_REGBUS_RB_WADDR   : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_WDATA   : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WACK    : out std_logic;
      TIMESTAMP_I         : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
      RX_MARKER_I         : in std_logic_vector(C_NUM_MARKER-1 downto 0);
      FIFO_COUNT_I        : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      PISO_I              : in  std_logic_vector(C_NUM_UART-1 downto 0);
      LOOPBACK_I          : in  std_logic_vector(C_NUM_UART-1 downto 0)
    );
  end component;

  constant PERIOD : time := 10 ns;    -- 100 MHz
  constant BIT_T  : time := 100 ns;   -- 10 MHz UART

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal done      : boolean := false;
  signal cycle     : unsigned(63 downto 0) := (others => '0');  -- timestamp: clock cycles
  signal baud      : std_logic := '0';

  signal tdata     : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0);
  signal tvalid    : std_logic;
  signal tready    : std_logic := '1';
  signal tkeep     : std_logic_vector(C_RX_AXIS_WIDTH/8-1 downto 0);
  signal tlast     : std_logic;

  signal raddr     : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal rupdate   : std_logic := '0';
  signal rdata     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal rack      : std_logic;
  signal waddr     : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal wupdate   : std_logic := '0';
  signal wdata     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal wack      : std_logic;

  signal marker    : std_logic_vector(C_NUM_MARKER-1 downto 0) := (others => '0');
  signal fifo_cnt  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal piso      : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '1');
  signal loopback  : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '1');

  -- UART senders, one per channel:  set tx_word(c) etc., then toggle tx_req(c)
  type word_array_t is array (0 to C_NUM_UART-1) of std_logic_vector(63 downto 0);
  type time_array_t is array (0 to C_NUM_UART-1) of time;
  signal tx_word   : word_array_t := (others => (others => '0'));
  signal tx_delay  : time_array_t := (others => 0 ns);         -- before the start bit
  signal tx_pulse  : time_array_t := (others => 0 ns);         -- if set:  one low pulse this long, no frame
  signal tx_stop   : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '1');  -- stop bit value
  signal tx_glitch : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '0');  -- 1-cycle glitch mid bit 10
  signal tx_lb     : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '0');  -- send on LOOPBACK_I instead
  signal tx_req    : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '0');
  type int_array_t is array (0 to C_NUM_UART-1) of integer;
  type sweep_t is array (0 to 5) of std_logic_vector(9 downto 0);   -- noisy PHASEs, per swept UART
  type sweep_int_t is array (0 to 5) of integer;
  signal tx_count  : int_array_t := (others => 1);  -- frames back to back, word + k for frame k
  signal tx_busy   : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '0');
  signal tx_stop_cycle : uart_reg_array_t;  -- cycle when the stop bit started (low 32 bits)

  -- AXI stream monitor: every beat, in order
  constant MAX_BEATS : integer := 8192;
  type beat_data_t is array (0 to MAX_BEATS-1) of std_logic_vector(63 downto 0);
  shared variable beat_data : beat_data_t;
  shared variable beat_last : std_logic_vector(0 to MAX_BEATS-1);
  shared variable beat_keep_ok : boolean := true;
  signal nbeats    : integer := 0;

  -- register addresses
  function rx_addr(chan : integer; reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_UPPER_RX * 16#4000# + chan * 16#100# + reg, 16));
  end function;
  constant COMMON    : integer := C_CHAN_GLOBAL;
  constant BROADCAST : integer := C_CHAN_BROADCAST;

  -- UART_CONFIG fields (rx_chan.vhd): period(23:16) flags(15:14) mode(13:12) input(11:8) phase(7:0)
  constant CFG_DEFAULT  : std_logic_vector(31 downto 0) := x"000A1104";
  constant CFG_OFF      : std_logic_vector(31 downto 0) := x"000A0104";  -- mode 00
  constant CFG_LOOPBACK : std_logic_vector(31 downto 0) := x"000A1204";  -- input 0010
  constant CFG_PATTERN  : std_logic_vector(31 downto 0) := x"000A1404";  -- input 0100
  constant CFG_IDLE_IN  : std_logic_vector(31 downto 0) := x"000A1004";  -- input 0000: fixed '1'

  function u64(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 64));
  end function;

  -- expected data header (rx_header.vhd):  type byte, PACMAN id, channel id, upper 32 bits zero
  function data_header(wtype : integer; pacman : integer; chan_id : integer) return std_logic_vector is
  begin
    return x"00000000" & std_logic_vector(to_unsigned(chan_id, 16)) & std_logic_vector(to_unsigned(pacman, 8))
      & std_logic_vector(to_unsigned(wtype, 8));
  end function;

begin
  uut: rx_unit port map (
    ACLK                => clk,
    RST_I               => rst,
    BAUD_I              => baud,
    M_AXIS_TDATA        => tdata,
    M_AXIS_TVALID       => tvalid,
    M_AXIS_TREADY       => tready,
    M_AXIS_TKEEP        => tkeep,
    M_AXIS_TLAST        => tlast,
    S_REGBUS_RB_RADDR   => raddr,
    S_REGBUS_RB_RDATA   => rdata,
    S_REGBUS_RB_RUPDATE => rupdate,
    S_REGBUS_RB_RACK    => rack,
    S_REGBUS_RB_WUPDATE => wupdate,
    S_REGBUS_RB_WADDR   => waddr,
    S_REGBUS_RB_WDATA   => wdata,
    S_REGBUS_RB_WACK    => wack,
    TIMESTAMP_I         => std_logic_vector(cycle),
    RX_MARKER_I         => marker,
    FIFO_COUNT_I        => fifo_cnt,
    PISO_I              => piso,
    LOOPBACK_I          => loopback
  );

  clock_until(clk, done, PERIOD);

  -- free-running cycle counter (the timestamp) and a one-cycle BAUD pulse
  -- every 10 cycles, as from the timing unit (ATC_CONFIG_BAUD default 0xA)
  process(clk)
  begin
    if rising_edge(clk) then
      cycle <= cycle + 1;
      if cycle mod 10 = 9 then
        baud <= '1';
      else
        baud <= '0';
      end if;
    end if;
  end process;

  -- AXI stream monitor
  process(clk)
  begin
    if rising_edge(clk) then
      if tvalid = '1' and tready = '1' then
        assert nbeats < MAX_BEATS report "too many beats" severity failure;
        beat_data(nbeats) := tdata;
        beat_last(nbeats) := tlast;
        if tkeep /= x"FF" then
          beat_keep_ok := false;
        end if;
        nbeats <= nbeats + 1;
      end if;
    end if;
  end process;

  -- UART senders
  gsend: for c in 0 to C_NUM_UART-1 generate
    process
      variable w : std_logic_vector(63 downto 0);
      procedure drive(v : std_logic) is
      begin
        if tx_lb(c) = '1' then
          loopback(c) <= v;
        else
          piso(c) <= v;
        end if;
      end procedure;
    begin
      wait on tx_req(c);
      tx_busy(c) <= '1';
      wait for tx_delay(c);
      if tx_pulse(c) > 0 ns then
        drive('0');
        wait for tx_pulse(c);
        drive('1');
      end if;
      for k in 0 to tx_count(c) - 1 loop
        exit when tx_pulse(c) > 0 ns;
        w := std_logic_vector(unsigned(tx_word(c)) + k);
        drive('0');                      -- start bit
        wait for BIT_T;
        for b in 0 to 63 loop
          drive(w(b));
          if b = 10 and tx_glitch(c) = '1' then
            wait for BIT_T/2;
            drive(not w(b));             -- one clock wide, at about the sample point
            wait for PERIOD;
            drive(w(b));
            wait for BIT_T/2 - PERIOD;
          else
            wait for BIT_T;
          end if;
        end loop;
        tx_stop_cycle(c) <= std_logic_vector(cycle(31 downto 0));
        drive(tx_stop(c));               -- stop bit
        wait for BIT_T;
      end loop;
      drive('1');                        -- idle
      wait for BIT_T;
      tx_busy(c) <= '0';
    end process;
  end generate;

  test: process
    variable rd_ptr : integer := 0;
    variable d      : std_logic_vector(31 downto 0);
    variable ok     : boolean;
    variable t      : integer;

    -- REGBUS write: one-cycle request, then wait for the acknowledge
    procedure reg_write(addr : std_logic_vector(15 downto 0); data : std_logic_vector(31 downto 0)) is
      variable acked : boolean := false;
    begin
      wait until falling_edge(clk);
      waddr   <= addr;
      wdata   <= data;
      wupdate <= '1';
      wait until falling_edge(clk);
      wupdate <= '0';
      for i in 1 to 8 loop
        wait until rising_edge(clk);
        if wack = '1' then
          acked := true;
          exit;
        end if;
      end loop;
      check(acked, "write to 0x" & hex(addr) & " acknowledged");
    end procedure;

    -- REGBUS read; acked = false if no acknowledge within 8 cycles
    procedure reg_read(addr : std_logic_vector(15 downto 0); data : out std_logic_vector(31 downto 0);
                       acked : out boolean; latency : out integer) is
    begin
      acked := false;
      data := (others => '0');
      latency := -1;
      wait until falling_edge(clk);
      raddr   <= addr;
      rupdate <= '1';
      wait until falling_edge(clk);
      rupdate <= '0';
      -- latency: clock edges after the one that samples the request
      for i in 1 to 8 loop
        wait until rising_edge(clk);
        if rack = '1' then
          acked := true;
          data := rdata;
          latency := i;
          exit;
        end if;
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

    procedure send(c : integer; w : std_logic_vector(63 downto 0); delay : time := 0 ns) is
    begin
      tx_word(c)  <= w;
      tx_delay(c) <= delay;
      tx_req(c)   <= not tx_req(c);
      wait for 0 ns;
    end procedure;

    procedure wait_senders is
    begin
      wait for 1 ns;
      while tx_busy /= (tx_busy'range => '0') loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    -- next beat from the monitor (fails after timeout)
    procedure next_beat(data : out std_logic_vector(63 downto 0); last : out std_logic; timeout : time := 50 us) is
      variable deadline : time;
    begin
      deadline := now + timeout;
      while nbeats <= rd_ptr and now < deadline loop
        wait until rising_edge(clk);
      end loop;
      if nbeats > rd_ptr then
        data := beat_data(rd_ptr);
        last := beat_last(rd_ptr);
        rd_ptr := rd_ptr + 1;
      else
        check(false, "stream beat arrived (timed out)");
        data := (others => 'X');
        last := 'X';
      end if;
    end procedure;

    -- one 192-bit word: header, timestamp, data;  ts_lo/ts_hi bound the timestamp
    procedure expect_word(header : std_logic_vector(63 downto 0); data : std_logic_vector(63 downto 0);
                          ts_lo, ts_hi : integer; msg : string) is
      variable b : std_logic_vector(63 downto 0);
      variable l : std_logic;
      variable ts : integer;
    begin
      next_beat(b, l);
      check_equal(b, header, msg & ": header");
      check_equal(l, '0', msg & ": no LAST on header");
      next_beat(b, l);
      if ts_lo >= 0 then
        ts := to_integer(unsigned(b(30 downto 0)));
        check(ts >= ts_lo and ts <= ts_hi and b(63 downto 31) = (63 downto 31 => '0'),
              msg & ": timestamp " & integer'image(ts) & " in [" & integer'image(ts_lo) & ", " & integer'image(ts_hi) & "]");
      end if;
      check_equal(l, '0', msg & ": no LAST on timestamp");
      next_beat(b, l);
      check_equal(b, data, msg & ": data");
      check_equal(l, '0', msg & ": no LAST on data");
    end procedure;

    -- trailer: EOP header, word count, then an empty fragment with LAST
    procedure expect_trailer(count : integer; pacman : integer := 0; msg : string := "trailer") is
      variable b : std_logic_vector(63 downto 0);
      variable l : std_logic;
    begin
      next_beat(b, l);
      check_equal(b, x"00000000" & x"0000" & std_logic_vector(to_unsigned(pacman, 8)) & x"4C", msg & ": EOP header");
      check_equal(l, '0', msg & ": no LAST on EOP header");
      next_beat(b, l);
      check_equal(b, u64(count), msg & ": word count");
      check_equal(l, '0', msg & ": no LAST on word count");
      next_beat(b, l);
      check_equal(b, u64(0), msg & ": last fragment");
      check_equal(l, '1', msg & ": LAST on last fragment");
    end procedure;

    procedure expect_quiet(t : time; msg : string) is
      variable n0 : integer;
    begin
      n0 := nbeats;
      wait for t;
      check_equal(nbeats, n0, msg & ": no stream output");
    end procedure;

    procedure check_counts(c : integer; starts, beats, updates, lost, frame_err : integer; msg : string) is
    begin
      wait for 100 ns;   -- counters are registered twice
      check_reg(rx_addr(c, C_ADDR_RX_UART_STARTS),    std_logic_vector(to_unsigned(starts, 32)),    msg & ": STARTS");
      check_reg(rx_addr(c, C_ADDR_RX_UART_BEATS),     std_logic_vector(to_unsigned(beats, 32)),     msg & ": BEATS");
      check_reg(rx_addr(c, C_ADDR_RX_UART_UPDATES),   std_logic_vector(to_unsigned(updates, 32)),   msg & ": UPDATES");
      check_reg(rx_addr(c, C_ADDR_RX_UART_LOST),      std_logic_vector(to_unsigned(lost, 32)),      msg & ": LOST");
      check_reg(rx_addr(c, C_ADDR_RX_UART_FRAME_ERR), std_logic_vector(to_unsigned(frame_err, 32)), msg & ": FRAME_ERR");
    end procedure;

    procedure zero_counts is
    begin
      reg_write(rx_addr(COMMON, C_ADDR_RX_ZERO_CNTS), x"00000000");
    end procedure;

    -- consume whatever the stream holds
    procedure drain is
    begin
      rd_ptr := nbeats;
    end procedure;

    -- a frame on UART c whose bit edges fall k clocks (plus 3 ns) after a BAUD period starts
    procedure send_at(c : integer; w : std_logic_vector(63 downto 0); k : integer) is
    begin
      wait until rising_edge(clk) and to_integer(cycle mod 10) = 0;
      send(c, w, k * PERIOD + 3 ns);
    end procedure;

    -- read the stream until it has been quiet for 3 us (a trailer's timeout is 2.56 us):  per UART, the words equal
    -- to w (got) and the others (bad);  trailers skipped
    procedure collect(w : std_logic_vector(63 downto 0); got, bad : inout int_array_t) is
      variable h, b : std_logic_vector(63 downto 0);
      variable l    : std_logic;
      variable n0   : integer;
      variable c    : integer;
    begin
      got := (others => 0);
      bad := (others => 0);
      loop
        n0 := nbeats;
        wait for 3 us;
        exit when nbeats = n0;
      end loop;
      while nbeats - rd_ptr >= 3 loop
        next_beat(h, l);
        next_beat(b, l);
        next_beat(b, l);
        if h(7 downto 0) /= x"4C" then
          c := to_integer(unsigned(h(31 downto 16))) - 1;
          if c >= 0 and c < C_NUM_UART then
            if b = w then
              got(c) := got(c) + 1;
            else
              bad(c) := bad(c) + 1;
            end if;
          end if;
        end if;
      end loop;
      check(nbeats = rd_ptr, "the stream ends on a whole word");
    end procedure;

    -- PHASE sweeps on six UARTs at once (the simulation costs per clock, not per busy UART):  MODE 1 on UARTs 18-20,
    -- MODE 2 on 21-23, start bits at offsets 0, 3, 6 clocks after a BAUD period starts.  Per UART and PHASE:  intact
    -- (no noise, the word once) or noisy;  edge = the start bit's phase as MODE 1 reports it (UART_STATUS EDGE)
    procedure phase_sweeps(noisy : out sweep_t; edge : out sweep_int_t) is
      constant W  : std_logic_vector(63 downto 0) := x"5555555555555555";   -- an edge every bit
      variable got, bad : int_array_t;
      variable v  : std_logic_vector(31 downto 0);
      variable ok : boolean;
      variable lt : integer;
      variable c  : integer;
      function sweep_tag(i, p : integer) return string is
      begin
        return "MODE " & integer'image(1 + i / 3) & ", offset " & integer'image(3 * (i mod 3)) & ", PHASE " &
               integer'image(p);
      end function;
      procedure send_all is
      begin
        wait until rising_edge(clk) and to_integer(cycle mod 10) = 0;
        for i in 0 to 5 loop
          send(18 + i, W, 3 * (i mod 3) * PERIOD + 3 ns);
        end loop;
        wait_senders;
      end procedure;
    begin
      for i in 0 to 5 loop
        reg_write(rx_addr(18 + i, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);
      end loop;
      send_all;
      collect(W, got, bad);
      for i in 0 to 5 loop
        c := 18 + i;
        check(got(c) = 1 and bad(c) = 0, "MODE 1 reference, UART " & integer'image(c) & ":  the word once");
        reg_read(rx_addr(c, C_ADDR_RX_UART_STATUS), v, ok, lt);
        edge(i) := to_integer(unsigned(v(31 downto 24)));
      end loop;
      for p in 0 to 9 loop
        zero_counts;
        for i in 0 to 5 loop
          reg_write(rx_addr(18 + i, C_ADDR_RX_UART_CONFIG), x"000A" & std_logic_vector(to_unsigned(1 + i / 3, 4)) &
                    x"1" & std_logic_vector(to_unsigned(p, 8)));
        end loop;
        send_all;
        wait for 8 us;                     -- a frame started off the edges ends on the idle line
        collect(W, got, bad);
        for i in 0 to 5 loop
          c := 18 + i;
          if i < 3 then
            req("RX-2.1");
          else
            req("RX-2.5");
          end if;
          reg_read(rx_addr(c, C_ADDR_RX_UART_NOISE), v, ok, lt);
          if unsigned(v) = 0 then
            noisy(i)(p) := '0';
            check(got(c) = 1 and bad(c) = 0, sweep_tag(i, p) & ":  no noise, the word intact, once");
            check_counts(c, 1, 1, 1, 0, 0, sweep_tag(i, p));
          else
            noisy(i)(p) := '1';
          end if;
        end loop;
      end loop;
      for i in 0 to 5 loop
        reg_write(rx_addr(18 + i, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);
      end loop;
    end procedure;

    -- n frames back to back on all 40 UARTs at once;  every word must reach the stream once, in order per UART
    procedure full_rate(n : integer; config : std_logic_vector(31 downto 0); msg : string) is
      variable got   : int_array_t := (others => 0);
      variable words : integer := 0;
      variable fin  : boolean := false;
      variable h, b  : std_logic_vector(63 downto 0);
      variable l     : std_logic;
      variable c     : integer;
    begin
      zero_counts;
      reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), config);
      for u in 0 to C_NUM_UART-1 loop
        tx_count(u) <= n;
      end loop;
      for u in 0 to C_NUM_UART-1 loop
        send(u, x"FA57" & std_logic_vector(to_unsigned(u, 16)) & x"00000000");
      end loop;
      while not fin loop
        next_beat(h, l);
        if h(7 downto 0) = x"4C" then             -- trailer
          next_beat(b, l);
          next_beat(b, l);
          fin := words >= n * C_NUM_UART;
        else
          next_beat(b, l);
          next_beat(b, l);
          c := to_integer(unsigned(h(31 downto 16))) - 1;
          if c >= 0 and c < C_NUM_UART then
            check_equal(b, x"FA57" & std_logic_vector(to_unsigned(c, 16)) & std_logic_vector(to_unsigned(got(c), 32)),
                        msg & ":  UART " & integer'image(c) & " word " & integer'image(got(c)));
            got(c) := got(c) + 1;
          else
            check(false, msg & ":  header with a channel id out of range");
          end if;
          words := words + 1;
        end if;
      end loop;
      wait_senders;
      for u in 0 to C_NUM_UART-1 loop
        check_equal(got(u), n, msg & ":  words from UART " & integer'image(u));
        check_counts(u, n, n, n, 0, 0, msg & ":  UART " & integer'image(u) & ", none lost");
        tx_count(u) <= 1;
      end loop;
      reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000001");
    end procedure;

    variable b    : std_logic_vector(63 downto 0);
    variable l    : std_logic;
    variable stop : integer;
    variable sw   : sweep_t;
    variable se   : sweep_int_t;
    variable got_w, bad_w : int_array_t;
    variable ex   : std_logic_vector(9 downto 0);
    type st_t is array (0 to 9) of integer;
    variable st   : st_t;
    variable sts  : string(1 to 10);
    variable n    : integer;
    type dts_t is array (0 to 1, 0 to 1) of integer;
    variable dts  : dts_t;
    variable lat  : integer;
    variable n0   : integer;
    variable hb   : integer;
    variable ts1, ts2 : integer;
  begin
    rst <= '1';
    wait for 10 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 10 * PERIOD;

    ---------------------------------------------------------------------
    print("-- register defaults (common.vhd, rx_registers.vhd)");
    req("REG-4.1");
    check_reg(rx_addr(0,  C_ADDR_RX_UART_CONFIG), CFG_DEFAULT, "UART_CONFIG ch0 default");
    check_reg(rx_addr(39, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT, "UART_CONFIG ch39 default");
    check_reg(rx_addr(0,  C_ADDR_RX_UART_CHAN), x"00000001", "UART_CHAN ch0 default (channel + 1)");
    check_reg(rx_addr(39, C_ADDR_RX_UART_CHAN), x"00000028", "UART_CHAN ch39 default (channel + 1)");
    check_reg(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG),    x"00000001", "BUFFER_CONFIG default");
    check_reg(rx_addr(COMMON, C_ADDR_RX_BUFFER_ENABLES),   x"00000000", "BUFFER_ENABLES default");
    check_reg(rx_addr(COMMON, C_ADDR_RX_PACMAN),           x"00000000", "PACMAN default");
    check_reg(rx_addr(COMMON, C_ADDR_RX_WORD_TYPE_LUT),    x"44444444", "WORD_TYPE_LUT default");
    check_reg(rx_addr(COMMON, C_ADDR_RX_HEARTBEAT_CONFIG), x"3B9ACA00", "HEARTBEAT_CONFIG default");
    check_reg(rx_addr(COMMON, C_ADDR_RX_ROLLOVER_CONFIG),  x"00000001", "ROLLOVER_CONFIG default");
    check_reg(rx_addr(COMMON, C_ADDR_RX_HEADER_A),         x"00480053", "HEADER_A default (heartbeat)");
    check_reg(rx_addr(COMMON, C_ADDR_RX_HEADER_B),         x"00530053", "HEADER_B default (rollover)");
    check_reg(rx_addr(COMMON, C_ADDR_RX_HEADER_C),         x"00000054", "HEADER_C default (trigger)");
    check_reg(rx_addr(COMMON, C_ADDR_RX_EOP_HEADER),       x"0000004C", "EOP_HEADER default");
    check_reg(rx_addr(COMMON, C_ADDR_RX_FIFO_CNT),         x"00000000", "FIFO_CNT");

    print("-- REGBUS behaviour");
    req("REG-3.1");
    reg_read(rx_addr(COMMON, C_ADDR_RX_PACMAN), d, ok, lat);
    -- current behaviour: RX answers two cycles after the request (extra output register)
    check_equal(lat, 2, "read acknowledge latency (cycles after the request)");
    req("REG-1.2");
    reg_read(rx_addr(COMMON, 16#FC#), d, ok, lat);
    check(not ok, "undefined RX register: no read acknowledge");
    reg_read(rx_addr(BROADCAST, C_ADDR_RX_UART_CONFIG), d, ok, lat);
    check(not ok, "broadcast channel is write only: no read acknowledge");
    reg_read(x"F020", d, ok, lat);
    check(not ok, "other scope (global): no read acknowledge from RX");
    reg_read(x"0004", d, ok, lat);
    check(not ok, "TX scope: no read acknowledge from RX");

    req("REG-2.1");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"123456A5");
    check_reg(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"123456A5", "PACMAN read back (all 32 bits kept)");
    reg_write(rx_addr(7, C_ADDR_RX_UART_CHAN), x"0000BEEF");
    check_reg(rx_addr(7, C_ADDR_RX_UART_CHAN), x"0000BEEF", "UART_CHAN ch7 read back");
    req("REG-2.3");
    reg_write(rx_addr(BROADCAST, C_ADDR_RX_UART_CONFIG), x"000A1105");
    check_reg(rx_addr(0,  C_ADDR_RX_UART_CONFIG), x"000A1105", "broadcast UART_CONFIG reaches ch0");
    check_reg(rx_addr(39, C_ADDR_RX_UART_CONFIG), x"000A1105", "broadcast UART_CONFIG reaches ch39");
    reg_write(rx_addr(BROADCAST, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);
    reg_write(rx_addr(7, C_ADDR_RX_UART_CHAN), x"00000008");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"00000000");

    ---------------------------------------------------------------------
    print("-- one word on one channel");
    req("RX-1.1");
    send(5, x"0123456789ABCDEF");
    wait_senders;
    stop := to_integer(unsigned(tx_stop_cycle(5)));
    expect_word(data_header(16#44#, 0, 6), x"0123456789ABCDEF", stop, stop + 15, "ch5 word");
    expect_trailer(1);
    req("RX-6.1");
    check_counts(5, 1, 1, 1, 0, 0, "ch5 after one word");
    check_counts(4, 0, 0, 0, 0, 0, "ch4 untouched");
    req("RX-1.1");
    check(beat_keep_ok, "TKEEP all ones on every beat");

    print("-- words on several channels at once come out in channel order, one packet");
    req("RX-1.2");
    send(39, x"3939393939393939");
    send(0,  x"0000000000000000");
    send(17, x"1717171717171717");
    wait_senders;
    expect_word(data_header(16#44#, 0, 1),  x"0000000000000000", -1, 0, "ch0 word");
    expect_word(data_header(16#44#, 0, 18), x"1717171717171717", -1, 0, "ch17 word");
    expect_word(data_header(16#44#, 0, 40), x"3939393939393939", -1, 0, "ch39 word");
    expect_trailer(3);

    print("-- every data bit position (walking ones and zeros)");
    req("RX-1.3");
    send(1, x"8000000000000001");
    send(2, x"7FFFFFFFFFFFFFFE");
    send(3, x"AAAAAAAAAAAAAAAA");
    send(4, x"5555555555555555");
    wait_senders;
    expect_word(data_header(16#44#, 0, 2), x"8000000000000001", -1, 0, "ch1 word");
    expect_word(data_header(16#44#, 0, 3), x"7FFFFFFFFFFFFFFE", -1, 0, "ch2 word");
    expect_word(data_header(16#44#, 0, 4), x"AAAAAAAAAAAAAAAA", -1, 0, "ch3 word");
    expect_word(data_header(16#44#, 0, 5), x"5555555555555555", -1, 0, "ch4 word");
    expect_trailer(4);

    print("-- word type LUT (indexed by data bits 1:0), PACMAN id, channel id");
    req("RX-1.4");
    reg_write(rx_addr(COMMON, C_ADDR_RX_WORD_TYPE_LUT), x"44434241");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"FFFFFF7E");
    reg_write(rx_addr(9, C_ADDR_RX_UART_CHAN), x"0000C0DE");
    send(8,  x"0000000000000010");
    send(9,  x"0000000000000011");
    send(10, x"0000000000000012");
    send(11, x"0000000000000013");
    wait_senders;
    expect_word(data_header(16#41#, 16#7E#, 9),      x"0000000000000010", -1, 0, "type 0 -> LUT byte 0");
    expect_word(data_header(16#42#, 16#7E#, 16#C0DE#), x"0000000000000011", -1, 0, "type 1 -> LUT byte 1, channel id");
    expect_word(data_header(16#43#, 16#7E#, 11),     x"0000000000000012", -1, 0, "type 2 -> LUT byte 2");
    expect_word(data_header(16#44#, 16#7E#, 12),     x"0000000000000013", -1, 0, "type 3 -> LUT byte 3");
    expect_trailer(4, 16#7E#, "trailer with PACMAN id");
    reg_write(rx_addr(COMMON, C_ADDR_RX_WORD_TYPE_LUT), x"44444444");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"00000000");
    reg_write(rx_addr(9, C_ADDR_RX_UART_CHAN), x"0000000A");

    print("-- trailer:  EOP_HEADER with the PACMAN id spliced in (bits 15-8), the word count, a zero fragment with LAST");
    req("RX-1.5");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"0000005A");
    reg_write(rx_addr(COMMON, C_ADDR_RX_EOP_HEADER), x"ABCD12E7");   -- bits 15-8 replaced by the PACMAN id
    send(20, x"2020202020202020");
    send(21, x"2121212121212121");
    wait_senders;
    expect_word(data_header(16#44#, 16#5A#, 21), x"2020202020202020", -1, 0, "trailer test, ch20 word");
    expect_word(data_header(16#44#, 16#5A#, 22), x"2121212121212121", -1, 0, "trailer test, ch21 word");
    next_beat(b, l);
    check_equal(b, x"00000000" & x"ABCD" & x"5A" & x"E7", "trailer:  EOP_HEADER template, PACMAN id in bits 15-8");
    check_equal(l, '0', "trailer:  no LAST on the header");
    next_beat(b, l);
    check_equal(b, u64(2), "trailer:  the packet's word count");
    check_equal(l, '0', "trailer:  no LAST on the count");
    next_beat(b, l);
    check_equal(b, u64(0), "trailer:  zero last fragment");
    check_equal(l, '1', "trailer:  LAST on the last fragment");
    reg_write(rx_addr(COMMON, C_ADDR_RX_EOP_HEADER), x"0000004C");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"00000000");

    print("-- timestamp:  latched at the stop bit's sample point (MODE 1:  PHASE after the edge)");
    req("RX-1.6");
    for pi in 0 to 1 loop
      for oi in 0 to 1 loop
        reg_write(rx_addr(27, C_ADDR_RX_UART_CONFIG), x"000A11" & std_logic_vector(to_unsigned(2 + 4 * pi, 8)));
        send_at(27, x"2727272727272727", 5 * oi);
        wait_senders;
        stop := to_integer(unsigned(tx_stop_cycle(27)));
        next_beat(b, l);
        check_equal(b, data_header(16#44#, 0, 28), "timestamp test:  header");
        next_beat(b, l);
        dts(pi, oi) := to_integer(unsigned(b(30 downto 0))) - stop;
        next_beat(b, l);
        check_equal(b, x"2727272727272727", "timestamp test:  data");
        expect_trailer(1);
        print("   PHASE " & integer'image(2 + 4 * pi) & ", offset " & integer'image(5 * oi) &
              ":  timestamp - stop bit start = " & integer'image(dts(pi, oi)) & " cycles");
        check(dts(pi, oi) - (2 + 4 * pi) >= 0 and dts(pi, oi) - (2 + 4 * pi) < 10,
              "timestamp within a bit period after the stop bit's sample point (PHASE " & integer'image(2 + 4 * pi) &
              ", offset " & integer'image(5 * oi) & ")");
      end loop;
    end loop;
    for oi in 0 to 1 loop
      check_equal(dts(1, oi) - dts(0, oi), 4, "timestamp moves with the sample point (PHASE 2 -> 6), offset " &
                  integer'image(5 * oi));
      check_equal(dts(oi, 1), dts(oi, 0), "timestamp relative to the stop bit independent of the offset, PHASE " &
                  integer'image(2 + 4 * oi));
    end loop;
    reg_write(rx_addr(27, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);

    print("-- LOOK registers: last word received on the selected channel");
    req("RX-6.2");
    reg_write(rx_addr(COMMON, C_ADDR_RX_LOOK_SELECT), x"00000005");
    check_reg(rx_addr(COMMON, C_ADDR_RX_LOOK_SELECT), x"00000005", "LOOK_SELECT read back");
    check_reg(rx_addr(COMMON, C_ADDR_RX_LOOK_LOWER), x"89ABCDEF", "LOOK_LOWER (ch5, low half)");
    check_reg(rx_addr(COMMON, C_ADDR_RX_LOOK_UPPER), x"01234567", "LOOK_UPPER (ch5, high half)");

    ---------------------------------------------------------------------
    print("-- UART start-bit phase: any phase relative to BAUD decodes (mode 01)");
    req("RX-2.1");
    zero_counts;
    for k in 0 to 9 loop                 -- UART k, start bit k clocks later than UART 0's
      send(k, x"F00DF00D0000000" & std_logic_vector(to_unsigned(k, 4)), k * PERIOD + 3 ns);
    end loop;
    wait_senders;
    for k in 0 to 9 loop
      expect_word(data_header(16#44#, 0, k + 1), x"F00DF00D0000000" & std_logic_vector(to_unsigned(k, 4)), -1, 0,
                  "phase " & integer'image(k));
    end loop;
    expect_trailer(10);
    for k in 0 to 9 loop
      check_counts(k, 1, 1, 1, 0, 0, "UART " & integer'image(k) & ", phase " & integer'image(k));
    end loop;
    -- PHASE sweeps, both modes at once (UARTs 18-23);  MODE 1:  the sample point is PHASE after the start bit's
    -- edge, so the noisy PHASEs are the same at every offset
    phase_sweeps(sw, se);
    req("RX-2.1");
    for i in 0 to 2 loop
      print("   MODE 1, offset " & integer'image(3 * i) & ":  edge " & integer'image(se(i)) & ", noisy PHASE " &
            hex("00" & sw(i)));
      check_equal(sw(i), sw(0), "MODE 1, offset " & integer'image(3 * i) & ":  noisy PHASEs independent of the offset");
      check_equal(se(i), (se(0) + 3 * i) mod 10, "MODE 1, offset " & integer'image(3 * i) & ":  edge phase follows");
    end loop;
    check(sw(0) /= "0000000000" and sw(0) /= "1111111111", "MODE 1:  some PHASEs noisy, others intact");

    print("-- MODE 10 (fixed phase):  the sample point is PHASE after BAUD, whatever the start bit's phase");
    req("RX-2.5");
    for i in 3 to 5 loop
      print("   MODE 2, offset " & integer'image(3 * (i - 3)) & ":  MODE 1 edge " & integer'image(se(i)) &
            ", noisy PHASE " & hex("00" & sw(i)));
      -- the noisy PHASEs are the two clocks of dissent at the bit edges, so they follow the start bit
      ex := (others => '0');
      ex((se(i) + 8) mod 10) := '1';
      ex((se(i) + 9) mod 10) := '1';
      check_equal(sw(i), ex, "MODE 2, offset " & integer'image(3 * (i - 3)) &
                  ":  noise only at the two PHASEs on the edges");
      check_equal(se(i), (se(3) + 3 * (i - 3)) mod 10, "MODE 2, offset " & integer'image(3 * (i - 3)) &
                  ":  edge phase follows");
    end loop;

    print("-- ACCEPT_DISSENT:  a start bit sampled with dissent (two of three taps low) starts a frame only if set");
    req("RX-2.6");
    -- UARTs 20-29 without the flag, 30-39 with it;  UART 20 + 10 f + o gets a two-clock low pulse at offset o (every
    -- vote of 0 on it dissents);  MODE 2, PHASE 4
    zero_counts;
    for i in 0 to 19 loop
      tx_pulse(20 + i) <= 2 * PERIOD;
      if i < 10 then
        reg_write(rx_addr(20 + i, C_ADDR_RX_UART_CONFIG), x"000A2104");
      else
        reg_write(rx_addr(20 + i, C_ADDR_RX_UART_CONFIG), x"000A6104");   -- and ACCEPT_DISSENT
      end if;
    end loop;
    wait until rising_edge(clk) and to_integer(cycle mod 10) = 0;
    for i in 0 to 19 loop
      send(20 + i, x"0000000000000000", (i mod 10) * PERIOD + 3 ns);
    end loop;
    wait_senders;
    wait for 8 us;
    -- the line is idle high after the pulse:  a start gives 64 ones and a good stop bit
    collect(x"FFFFFFFFFFFFFFFF", got_w, bad_w);
    for f in 0 to 1 loop
      sts := (others => ' ');
      n := 0;
      for o in 0 to 9 loop
        reg_read(rx_addr(20 + 10 * f + o, C_ADDR_RX_UART_STARTS), d, ok, t);
        st(o) := to_integer(unsigned(d));
        check(got_w(20 + 10 * f + o) = st(o) and bad_w(20 + 10 * f + o) = 0,
              "ACCEPT_DISSENT " & integer'image(f) & ", pulse at " & integer'image(o) & ":  a frame of ones per start");
        sts(o + 1) := character'val(character'pos('0') + st(o));
        n := n + st(o);
      end loop;
      print("   ACCEPT_DISSENT " & integer'image(f) & ":  starts per pulse offset 0-9:  " & sts);
      if f = 0 then
        check_equal(n, 0, "ACCEPT_DISSENT 0:  no start at any offset");
      else
        check_equal(n, 2, "ACCEPT_DISSENT 1:  a start at the two offsets that put the sample on the pulse");
      end if;
    end loop;
    for i in 0 to 19 loop
      tx_pulse(20 + i) <= 0 ns;
      reg_write(rx_addr(20 + i, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);
    end loop;

    print("-- a one-cycle glitch mid bit is outvoted (majority vote) and counted as noise");
    req("RX-2.2");
    zero_counts;
    tx_glitch(13) <= '1';
    send(13, x"0000000000000400");    -- bit 10 is 1, the glitch takes it to 0 for a cycle
    wait_senders;
    tx_glitch(13) <= '0';
    expect_word(data_header(16#44#, 0, 14), x"0000000000000400", -1, 0, "glitched word");
    expect_trailer(1);
    wait for 100 ns;
    reg_read(rx_addr(13, C_ADDR_RX_UART_NOISE), d, ok, lat);
    check(ok and unsigned(d) >= 1, "NOISE counted (got " & integer'image(to_integer(unsigned(d))) & ")");

    print("-- bad stop bit: frame error, no data");
    req("RX-2.3");
    zero_counts;
    tx_stop(14) <= '0';
    send(14, x"1111111111111111");
    wait_senders;
    tx_stop(14) <= '1';
    expect_quiet(10 us, "frame error");
    check_counts(14, 1, 0, 0, 0, 1, "ch14 after a frame error");

    print("-- MODE 00: channel off, input ignored");
    req("RX-2.4");
    zero_counts;
    reg_write(rx_addr(15, C_ADDR_RX_UART_CONFIG), CFG_OFF);
    send(15, x"2222222222222222");
    wait_senders;
    expect_quiet(10 us, "mode 00");
    check_counts(15, 0, 0, 0, 0, 0, "ch15 off");
    reg_write(rx_addr(15, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);

    print("-- INPUT select: 0000 fixed idle, 0010 loopback");
    req("RX-2.4");
    reg_write(rx_addr(16, C_ADDR_RX_UART_CONFIG), CFG_IDLE_IN);
    send(16, x"3333333333333333");
    wait_senders;
    expect_quiet(10 us, "input 0000");
    reg_write(rx_addr(16, C_ADDR_RX_UART_CONFIG), CFG_LOOPBACK);
    send(16, x"4444444444444444");    -- on PISO: ignored
    wait_senders;
    expect_quiet(10 us, "input 0010 ignores PISO");
    tx_lb(16) <= '1';
    send(16, x"5555555555555555");    -- on LOOPBACK_I
    wait_senders;
    tx_lb(16) <= '0';
    expect_word(data_header(16#44#, 0, 17), x"5555555555555555", -1, 0, "loopback word");
    expect_trailer(1);
    reg_write(rx_addr(16, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);

    ---------------------------------------------------------------------
    print("-- INPUT select with more than one bit set:  the line is held high, nothing is received");
    req("RX-2.7");
    for i in 0 to 1 loop
      zero_counts;
      if i = 0 then
        reg_write(rx_addr(23, C_ADDR_RX_UART_CONFIG), x"000A1304");    -- PISO and LOOPBACK
      else
        reg_write(rx_addr(23, C_ADDR_RX_UART_CONFIG), x"000A1F04");    -- all four
      end if;
      send(23, x"6666666666666666");      -- on PISO
      wait_senders;
      tx_lb(23) <= '1';
      send(23, x"7777777777777777");      -- on LOOPBACK_I
      wait_senders;
      tx_lb(23) <= '0';
      expect_quiet(10 us, "input " & integer'image(i));
      check_counts(23, 0, 0, 0, 0, 0, "input " & integer'image(i) & ":  no start");
    end loop;
    reg_write(rx_addr(23, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);

    print("-- stream stalled (FIFO full): one word waits in the rx_buffer, one in the channel, the next is lost");
    req("RX-3.1");
    zero_counts;
    wait until falling_edge(clk);
    tready <= '0';
    for k in 1 to 3 loop
      send(18, std_logic_vector(to_unsigned(k, 64)));
      wait_senders;
    end loop;
    wait for 1 us;
    -- 3 starts and updates, 1 beat (word 1 went into the rx_buffer), 1 lost (word 3)
    check_counts(18, 3, 1, 3, 1, 0, "ch18 with the stream stalled");
    wait until falling_edge(clk);
    tready <= '1';
    -- the stall outlasted the packet timeout, so word 1 closes its packet
    expect_word(data_header(16#44#, 0, 19), u64(1), -1, 0, "first word after the stall");
    expect_trailer(1, 0, "stall: packet 1");
    expect_word(data_header(16#44#, 0, 19), u64(2), -1, 0, "second word after the stall");
    expect_trailer(1, 0, "stall: packet 2");
    expect_quiet(10 us, "third word was lost");
    check_counts(18, 3, 2, 3, 1, 0, "ch18 after the stall");

    print("-- packet size limit (BUFFER_CONFIG MMMM = 2): 3 words -> packets of 2 and 1");
    req("RX-3.2");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00020001");
    send(20, u64(20));
    send(21, u64(21));
    send(22, u64(22));
    wait_senders;
    expect_word(data_header(16#44#, 0, 21), u64(20), -1, 0, "packet 1 word 1");
    expect_word(data_header(16#44#, 0, 22), u64(21), -1, 0, "packet 1 word 2");
    expect_trailer(2, 0, "packet 1 trailer");
    expect_word(data_header(16#44#, 0, 23), u64(22), -1, 0, "packet 2 word 1");
    expect_trailer(1, 0, "packet 2 trailer");

    print("-- packet timeout (BUFFER_CONFIG TTTT, units of 256 cycles): later words join the open packet");
    req("RX-3.3");
    -- TTTT counts units of 256 clock cycles (rx_buffer.vhd CONFIG_I)
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000004");   -- 4 x 256 cycles = 10.24 us
    send(23, u64(23));
    wait_senders;
    send(24, u64(24));                -- arrives ~7 us later: before the timeout
    wait_senders;
    expect_word(data_header(16#44#, 0, 24), u64(23), -1, 0, "timeout: word 1");
    expect_word(data_header(16#44#, 0, 25), u64(24), -1, 0, "timeout: word 2, same packet");
    expect_trailer(2, 0, "timeout trailer");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000001");
    send(23, u64(23));
    wait_senders;
    expect_word(data_header(16#44#, 0, 24), u64(23), -1, 0, "1 sweep: word 1");
    expect_trailer(1, 0, "1 sweep: own packet");
    send(24, u64(24));
    wait_senders;
    expect_word(data_header(16#44#, 0, 25), u64(24), -1, 0, "1 sweep: word 2");
    expect_trailer(1, 0, "1 sweep: own packet");
    -- the unit:  4 x 256 cycles + one sweep (136) = 11.6 us at most, so a word ~12.6 us later starts a new
    -- packet (with units of 512 cycles it would still join)
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000004");
    send(23, u64(23));
    wait_senders;
    wait for 6 us;
    send(24, u64(24));                -- arrives ~12.6 us later: after the timeout
    wait_senders;
    expect_word(data_header(16#44#, 0, 24), u64(23), -1, 0, "unit: word 1");
    expect_trailer(1, 0, "unit: word 1 closes its packet");
    expect_word(data_header(16#44#, 0, 25), u64(24), -1, 0, "unit: word 2");
    expect_trailer(1, 0, "unit: word 2 in a new packet");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000001");

    print("-- one word per packet (BUFFER_CONFIG MMMM = 1), all 40 UARTs sending back to back: no channel starves");
    req("RX-3.4");
    -- each packet resumes the sweep where the last one stopped:  about 10 cycles per word, 40 words well
    -- within one UART frame (660 cycles).  Restarting every packet at channel 0 would cost a growing scan
    -- per word (about 2700 cycles for 40), so the low channels' next words would starve the high ones (LOST).
    zero_counts;
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00010000");   -- 1 word per packet, no timeout
    for f in 1 to 3 loop
      for c in 0 to C_NUM_UART-1 loop
        send(c, u64(100 * f + c));
      end loop;
      wait_senders;
    end loop;
    for k in 1 to 3 * C_NUM_UART loop
      next_beat(b, l);
      next_beat(b, l);
      next_beat(b, l);
      expect_trailer(1, 0, "one word per packet");
    end loop;
    for c in 0 to C_NUM_UART-1 loop
      check_counts(c, 3, 3, 3, 0, 0, "ch" & integer'image(c) & ":  3 words, none lost");
    end loop;
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000001");

    print("-- full rate:  all 40 UARTs receiving back-to-back frames, the stream ready:  no word lost");
    req("RX-3.5");
    full_rate(5, x"00000001", "full rate");
    full_rate(3, x"00010000", "full rate, one word per packet");

    print("-- BUFFER_CONFIG zeros:  TIMEOUT 0 is no timeout, MAX_WORDS 0 no maximum;  both 0:  the packet never closes");
    req("RX-3.6");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00020000");   -- at most 2 words, no timeout
    send(24, x"2424242424242424");
    wait_senders;
    expect_word(data_header(16#44#, 0, 25), x"2424242424242424", -1, 0, "no timeout:  first word");
    expect_quiet(20 us, "no timeout:  the packet stays open");
    send(26, x"2626262626262626");
    wait_senders;
    expect_word(data_header(16#44#, 0, 27), x"2626262626262626", -1, 0, "no timeout:  second word");
    expect_trailer(2, 0, "no timeout:  closed by the maximum");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000001");   -- no maximum
    for u in 0 to C_NUM_UART-1 loop
      send(u, x"A11A" & std_logic_vector(to_unsigned(u, 16)) & x"00000000");
    end loop;
    wait_senders;
    for u in 0 to C_NUM_UART-1 loop
      expect_word(data_header(16#44#, 0, u + 1), x"A11A" & std_logic_vector(to_unsigned(u, 16)) & x"00000000", -1, 0,
                  "no maximum:  UART " & integer'image(u));
    end loop;
    expect_trailer(C_NUM_UART, 0, "no maximum:  40 words in one packet");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000000");   -- both 0
    send(24, x"2525252525252525");
    wait_senders;
    expect_word(data_header(16#44#, 0, 25), x"2525252525252525", -1, 0, "both 0:  the word");
    expect_quiet(20 us, "both 0:  the packet never closes");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_CONFIG), x"00000001");   -- a timeout closes it at once
    expect_trailer(1, 0, "both 0, then TIMEOUT 1");

    ---------------------------------------------------------------------
    print("-- heartbeat sync word (enable bit 0): HEADER_A with PACMAN id, timestamp, zero data");
    req("RX-4.1");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"00000033");
    reg_write(rx_addr(COMMON, C_ADDR_RX_HEARTBEAT_CONFIG), x"00000BB8");  -- 3000 cycles
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_ENABLES), x"00000001");
    expect_word(x"0000000000483353", u64(0), -1, 0, "heartbeat 1");
    expect_trailer(1, 16#33#, "heartbeat 1 trailer");
    next_beat(b, l);
    ts1 := 0;
    check_equal(b, x"0000000000483353", "heartbeat 2 header");
    next_beat(b, l);
    ts2 := to_integer(unsigned(b(30 downto 0)));
    next_beat(b, l);
    check_equal(b, u64(0), "heartbeat 2 data");
    expect_trailer(1, 16#33#, "heartbeat 2 trailer");
    next_beat(b, l);
    next_beat(b, l);
    ts1 := to_integer(unsigned(b(30 downto 0)));
    next_beat(b, l);
    expect_trailer(1, 16#33#, "heartbeat 3 trailer");
    check_equal(ts1 - ts2, 3000, "heartbeat period (cycles) = HEARTBEAT_CONFIG");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_ENABLES), x"00000000");
    wait for 40 us;   -- drain anything in flight
    rd_ptr := nbeats;
    expect_quiet(40 us, "heartbeat disabled");

    print("-- rollover sync word (enable bit 1): HEADER_B when the timestamp equals ROLLOVER_CONFIG");
    req("RX-4.2");
    t := to_integer(cycle(30 downto 0)) + 2000;   -- 20 us ahead
    reg_write(rx_addr(COMMON, C_ADDR_RX_ROLLOVER_CONFIG), std_logic_vector(to_unsigned(t, 32)));
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_ENABLES), x"00000002");
    expect_word(x"0000000000533353", u64(0), t, t, "rollover");
    expect_trailer(1, 16#33#, "rollover trailer");
    expect_quiet(20 us, "rollover only once");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_ENABLES), x"00000000");

    print("-- markers (enable bits 2, 3; RX_MARKER_I(2), (3)): HEADER_C, HEADER_D");
    req("RX-4.3");
    reg_write(rx_addr(COMMON, C_ADDR_RX_HEADER_D), x"00000058");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_ENABLES), x"0000000C");
    wait until falling_edge(clk);
    marker(2) <= '1';
    t := to_integer(cycle(30 downto 0));
    wait until falling_edge(clk);
    marker(2) <= '0';
    expect_word(x"0000000000003354", u64(0), t, t + 3, "marker 2 (trigger)");
    expect_trailer(1, 16#33#, "marker 2 trailer");
    wait until falling_edge(clk);
    marker(3) <= '1';
    wait until falling_edge(clk);
    marker(3) <= '0';
    expect_word(x"0000000000003358", u64(0), -1, 0, "marker 3");
    expect_trailer(1, 16#33#, "marker 3 trailer");
    wait until falling_edge(clk);
    marker(0) <= '1';
    marker(1) <= '1';
    wait until falling_edge(clk);
    marker(0) <= '0';
    marker(1) <= '0';
    expect_quiet(10 us, "markers 0 and 1 not used by the RX unit");
    reg_write(rx_addr(COMMON, C_ADDR_RX_BUFFER_ENABLES), x"00000000");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"00000000");

    ---------------------------------------------------------------------
    print("-- pattern generator into a channel (INPUT 0100)");
    req("RX-5.1");
    zero_counts;
    reg_write(rx_addr(COMMON, C_ADDR_RX_PATTERN_LOWER), x"DEADBEEF");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PATTERN_UPPER), x"C0FFEE00");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PATTERN_DELAY), x"00000064");   -- 100 bit times between words
    reg_write(rx_addr(25, C_ADDR_RX_UART_CONFIG), CFG_PATTERN);
    -- current behaviour:  a write that turns the generator on and moves its phase can give the BAUD period
    -- two clk_en pulses (old phase, then new), cutting the first start bit short;  depending on where the
    -- write lands, the first word is then received shifted.  So the phase goes in first, then the mode.
    reg_write(rx_addr(COMMON, C_ADDR_RX_PATTERN_CONFIG), x"00000004");   -- phase 4, generator off
    reg_write(rx_addr(COMMON, C_ADDR_RX_PATTERN_CONFIG), x"00000104");   -- mode 0001 (bits 11:8), phase 4
    for k in 1 to 3 loop
      expect_word(data_header(16#44#, 0, 26), x"C0FFEE00DEADBEEF", -1, 0, "pattern word " & integer'image(k));
      expect_trailer(1);
    end loop;
    reg_write(rx_addr(COMMON, C_ADDR_RX_PATTERN_CONFIG), x"00000000");
    wait for 20 us;
    rd_ptr := nbeats;
    reg_read(rx_addr(COMMON, C_ADDR_RX_PATTERN_STARTS), d, ok, lat);
    check(ok and unsigned(d) >= 3, "PATTERN_STARTS >= 3 (got " & integer'image(to_integer(unsigned(d))) & ")");
    reg_read(rx_addr(COMMON, C_ADDR_RX_PATTERN_STOPS), d, ok, lat);
    check(ok and unsigned(d) >= 3, "PATTERN_STOPS >= 3 (got " & integer'image(to_integer(unsigned(d))) & ")");
    reg_write(rx_addr(25, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT);

    print("-- status registers:  UART status (state bits 1:0) mid-frame and idle");
    req("RX-6.3");
    send(30, u64(30));
    wait for 3 us;                                 -- inside the 66-bit frame (100 ns per bit)
    reg_read(rx_addr(30, C_ADDR_RX_UART_STATUS), d, ok, lat);
    check(ok, "UART 30 status acknowledged");
    check_equal(d(1 downto 0), "10", "UART 30 mid-frame:  state DATA");
    reg_read(rx_addr(31, C_ADDR_RX_UART_STATUS), d, ok, lat);
    check_equal(d(1 downto 0), "00", "UART 31 (no input):  state IDLE");
    wait_senders;
    expect_word(data_header(16#44#, 0, 31), u64(30), -1, 0, "status test word");
    expect_trailer(1);
    reg_read(rx_addr(30, C_ADDR_RX_UART_STATUS), d, ok, lat);
    check_equal(d(1 downto 0), "00", "UART 30 after the frame:  state IDLE");
    check_equal(d(2), '0', "UART 30 after the frame:  word taken (valid low)");

    print("-- buffer status (state bits 2:0, tvalid bit 3, tready bit 4):  stalled, then idle");
    req("RX-6.3");
    wait until falling_edge(clk);
    tready <= '0';
    send(32, u64(32));
    wait_senders;
    wait for 1 us;
    reg_read(rx_addr(COMMON, C_ADDR_RX_BUFFER_STATUS), d, ok, lat);
    check(ok, "buffer status acknowledged");
    check_equal(d(2 downto 0), "010", "stalled:  state STREAM");
    check_equal(d(3), '1', "stalled:  tvalid high");
    check_equal(d(4), '0', "stalled:  tready low");
    wait until falling_edge(clk);
    tready <= '1';
    expect_word(data_header(16#44#, 0, 33), u64(32), -1, 0, "word after the buffer-status stall");
    expect_trailer(1);
    wait for 1 us;
    reg_read(rx_addr(COMMON, C_ADDR_RX_BUFFER_STATUS), d, ok, lat);
    check_equal(d(2 downto 0), "000", "after the packet:  state IDLE");
    check_equal(d(3), '0', "after the packet:  tvalid low");

    print("-- pattern status:  generator off, line idle high (bit 8), no start/stop flags");
    req("RX-5.1");
    reg_read(rx_addr(COMMON, C_ADDR_RX_PATTERN_STATUS), d, ok, lat);
    check(ok, "pattern status acknowledged");
    check_equal(d(8), '1', "pattern line idle high");
    check_equal(d(1 downto 0), "00", "no start/stop flag");

    print("-- FIFO count (an input) and FIFO_MAX, the largest count since ZERO_CNTS");
    req("RX-6.4");
    zero_counts;
    wait until falling_edge(clk);
    fifo_cnt <= x"00000010";
    wait for 50 ns;
    check_reg(rx_addr(COMMON, C_ADDR_RX_FIFO_CNT), x"00000010", "FIFO_CNT follows the input");
    wait until falling_edge(clk);
    fifo_cnt <= x"00000100";
    wait for 50 ns;
    wait until falling_edge(clk);
    fifo_cnt <= x"00000020";
    wait for 50 ns;
    check_reg(rx_addr(COMMON, C_ADDR_RX_FIFO_CNT), x"00000020", "FIFO_CNT follows the input");
    check_reg(rx_addr(COMMON, C_ADDR_RX_FIFO_MAX), x"00000100", "FIFO_MAX holds the peak");
    zero_counts;
    wait for 50 ns;
    check_reg(rx_addr(COMMON, C_ADDR_RX_FIFO_MAX), x"00000020", "current behaviour:  after ZERO_CNTS, FIFO_MAX restarts at the current count");
    wait until falling_edge(clk);
    fifo_cnt <= (others => '0');

    print("-- ZERO_CNTS clears the counters");
    req("RX-6.1");
    check_counts(5, 0, 0, 0, 0, 0, "ch5 after earlier ZERO_CNTS");
    send(5, u64(5));
    wait_senders;
    expect_word(data_header(16#44#, 0, 6), u64(5), -1, 0, "ch5 again");
    expect_trailer(1);
    check_counts(5, 1, 1, 1, 0, 0, "ch5 counted");
    zero_counts;
    check_counts(5, 0, 0, 0, 0, 0, "ch5 zeroed");

    print("-- reset restores the defaults");
    req("REG-4.1");
    reg_write(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"000000AA");
    reg_write(rx_addr(3, C_ADDR_RX_UART_CONFIG), CFG_OFF);
    wait until falling_edge(clk);
    rst <= '1';
    wait for 5 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 5 * PERIOD;
    check_reg(rx_addr(COMMON, C_ADDR_RX_PACMAN), x"00000000", "PACMAN after reset");
    check_reg(rx_addr(3, C_ADDR_RX_UART_CONFIG), CFG_DEFAULT, "UART_CONFIG ch3 after reset");
    check_reg(rx_addr(COMMON, C_ADDR_RX_HEADER_D), x"00000000", "HEADER_D after reset");
    req("RX-1.1");

    check(beat_keep_ok, "TKEEP all ones on every beat");
    finish("rx_unit_check");
    done <= true;
    wait;
  end process;
end behaviour;

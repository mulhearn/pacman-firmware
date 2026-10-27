-- tx_unit_check:  unit test for the TX unit (black box at the tx_unit ports)
--
-- Sends DMA packets into the AXI stream (41 beats of 64 bits: the channel
-- mask, then one word per UART channel 0..39), decodes every POSI line as a
-- UART (start bit, 64 data bits LSB first, stop bit, one bit per BAUD
-- period), and checks which channels transmit what, in which order, with
-- which timing; plus the registers (defaults, config, broadcast, counters,
-- look registers, ZERO_CNTS) over the REGBUS.
--
-- Contracts come from the RTL comments (tx_buffer.vhd, tx_chan.vhd,
-- tx_registers.vhd, register_map.vhd, common.vhd).  Where they were
-- ambiguous the test pins down current behaviour and says so ("current
-- behaviour:").  Stimulus changes on falling clock edges (see rx_unit_check).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity tx_unit_check is
end tx_unit_check;

architecture behaviour of tx_unit_check is
  component tx_unit is
    port (
      ACLK                : in std_logic;
      RST_I               : in std_logic;
      BAUD_I              : in  std_logic;
      S_AXIS_TDATA        : in std_logic_vector(C_TX_AXIS_WIDTH-1 downto 0);
      S_AXIS_TVALID       : in std_logic;
      S_AXIS_TREADY       : out std_logic;
      S_AXIS_TKEEP        : in std_logic_vector(C_TX_AXIS_WIDTH/8-1 downto 0);
      S_AXIS_TLAST        : in std_logic;
      S_REGBUS_RB_RADDR   : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_RDATA   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RUPDATE : in  std_logic;
      S_REGBUS_RB_RACK    : out std_logic;
      S_REGBUS_RB_WUPDATE : in  std_logic;
      S_REGBUS_RB_WADDR   : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_WDATA   : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WACK    : out std_logic;
      POSI_O              : out std_logic_vector(C_NUM_UART-1 downto 0);
      DEBUG_O             : out  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
    );
  end component;

  constant PERIOD : time := 10 ns;    -- 100 MHz; BAUD every 10 cycles = 10 MHz UART

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal done      : boolean := false;
  signal cycle     : integer := 0;
  signal baud      : std_logic := '0';

  signal tdata     : std_logic_vector(C_TX_AXIS_WIDTH-1 downto 0) := (others => '0');
  signal tvalid    : std_logic := '0';
  signal tready    : std_logic;
  signal tlast     : std_logic := '0';

  signal raddr     : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal rupdate   : std_logic := '0';
  signal rdata     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal rack      : std_logic;
  signal waddr     : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal wupdate   : std_logic := '0';
  signal wdata     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal wack      : std_logic;

  signal posi      : std_logic_vector(C_NUM_UART-1 downto 0);

  -- UART decoders: every frame seen on each POSI line
  constant MAX_FRAMES : integer := 16;
  type frame_words_t is array (0 to C_NUM_UART-1, 0 to MAX_FRAMES-1) of std_logic_vector(63 downto 0);
  type frame_times_t is array (0 to C_NUM_UART-1, 0 to MAX_FRAMES-1) of integer;
  shared variable rx_word  : frame_words_t;
  shared variable rx_start : frame_times_t;   -- cycle of the start bit's falling edge
  shared variable rx_end   : frame_times_t;   -- cycle the stop bit started
  type count_array_t is array (0 to C_NUM_UART-1) of integer;
  signal nframes   : count_array_t := (others => 0);
  signal bad_stop  : count_array_t := (others => 0);

  function tx_addr(chan : integer; reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_UPPER_TX * 16#4000# + chan * 16#100# + reg, 16));
  end function;
  constant COMMON    : integer := C_CHAN_GLOBAL;
  constant BROADCAST : integer := C_CHAN_BROADCAST;

  function sl(b : boolean) return std_logic is
  begin
    if b then return '1'; end if;
    return '0';
  end function;

  -- a recognisable word per channel and packet
  function word(c : integer; k : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(16#A5# + k, 8)) & x"5A" & std_logic_vector(to_unsigned(c, 8))
      & std_logic_vector(to_unsigned(k, 8)) & x"8001" & std_logic_vector(to_unsigned(c * 256 + k, 16));
  end function;

begin
  uut: tx_unit port map (
    ACLK                => clk,
    RST_I               => rst,
    BAUD_I              => baud,
    S_AXIS_TDATA        => tdata,
    S_AXIS_TVALID       => tvalid,
    S_AXIS_TREADY       => tready,
    S_AXIS_TKEEP        => x"FF",
    S_AXIS_TLAST        => tlast,
    S_REGBUS_RB_RADDR   => raddr,
    S_REGBUS_RB_RDATA   => rdata,
    S_REGBUS_RB_RUPDATE => rupdate,
    S_REGBUS_RB_RACK    => rack,
    S_REGBUS_RB_WUPDATE => wupdate,
    S_REGBUS_RB_WADDR   => waddr,
    S_REGBUS_RB_WDATA   => wdata,
    S_REGBUS_RB_WACK    => wack,
    POSI_O              => posi,
    DEBUG_O             => open
  );

  clock_until(clk, done, PERIOD);

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

  -- UART decoders, sampling in the middle of each 100 ns bit
  gdec: for c in 0 to C_NUM_UART-1 generate
    process
      variable w  : std_logic_vector(63 downto 0);
      variable n  : integer := 0;
      variable t0 : integer;
    begin
      wait until posi(c) = '0';
      t0 := cycle;
      wait for 50 ns;
      if posi(c) = '0' then             -- start bit
        for b in 0 to 63 loop
          wait for 100 ns;
          w(b) := posi(c);
        end loop;
        wait for 100 ns;
        if n < MAX_FRAMES then
          rx_word(c, n)  := w;
          rx_start(c, n) := t0;
          rx_end(c, n)   := cycle - 5;   -- we sample mid bit
        end if;
        if posi(c) /= '1' then
          bad_stop(c) <= bad_stop(c) + 1;
        end if;
        if posi(c) = '0' then
          wait until posi(c) = '1';
        end if;
        n := n + 1;
        nframes(c) <= n;
      end if;
    end process;
  end generate;

  test: process
    variable d   : std_logic_vector(31 downto 0);
    variable ok  : boolean;
    variable lat : integer;
    variable n0  : count_array_t;
    variable t   : integer;

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

    -- one AXI stream beat (waits for TREADY)
    procedure beat(data : std_logic_vector(63 downto 0); last : std_logic) is
    begin
      wait until falling_edge(clk);
      tdata  <= data;
      tvalid <= '1';
      tlast  <= last;
      loop
        wait until rising_edge(clk);
        exit when tready = '1';
      end loop;
      wait until falling_edge(clk);
      tvalid <= '0';
      tlast  <= '0';
    end procedure;

    -- DMA packet: mask, then words for channels 0..39 (word(c, k) where masked, else junk)
    procedure packet(mask : std_logic_vector(63 downto 0); k : integer) is
    begin
      beat(mask, '0');
      for c in 0 to C_NUM_UART-1 loop
        if mask(c) = '1' then
          beat(word(c, k), sl(c = C_NUM_UART-1));
        else
          beat(x"DEADDEADDEADDEAD", sl(c = C_NUM_UART-1));
        end if;
      end loop;
    end procedure;

    procedure snapshot is
    begin
      n0 := nframes;
    end procedure;

    -- wait until every channel has been quiet (line high) for a while
    procedure wait_idle is
      variable quiet : integer := 0;
    begin
      while quiet < 200 loop
        wait until rising_edge(clk);
        if posi = (posi'range => '1') then
          quiet := quiet + 1;
        else
          quiet := 0;
        end if;
      end loop;
    end procedure;

    procedure check_frames(c : integer; count : integer; msg : string) is
    begin
      check_equal(nframes(c) - n0(c), count, msg & ": frames on channel " & integer'image(c));
    end procedure;

    procedure check_word(c : integer; i : integer; expected : std_logic_vector(63 downto 0); msg : string) is
    begin
      if i < MAX_FRAMES then
        check_equal(rx_word(c, i), expected, msg & ": channel " & integer'image(c) & " frame " & integer'image(i));
      end if;
    end procedure;

    variable mask : std_logic_vector(63 downto 0);
    variable w    : std_logic_vector(63 downto 0);
  begin
    rst <= '1';
    wait for 10 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 10 * PERIOD;

    ---------------------------------------------------------------------
    print("-- register defaults, REGBUS behaviour");
    req("REG-4.1");
    check_reg(tx_addr(0,  C_ADDR_TX_UART_CONFIG), x"00000006", "UART_CONFIG ch0 default");
    check_reg(tx_addr(39, C_ADDR_TX_UART_CONFIG), x"00000006", "UART_CONFIG ch39 default");
    check_reg(tx_addr(COMMON, C_ADDR_TX_LOOK_SELECT), x"00000000", "LOOK_SELECT default");
    check_reg(tx_addr(0, C_ADDR_TX_UART_STARTS), x"00000000", "STARTS ch0 after reset");
    check_reg(tx_addr(0, C_ADDR_TX_UART_BEATS),  x"00000000", "BEATS ch0 after reset");
    req("REG-3.1");
    reg_read(tx_addr(COMMON, C_ADDR_TX_LOOK_SELECT), d, ok, lat);
    -- current behaviour: TX answers two cycles after the request (extra output register)
    check_equal(lat, 2, "read acknowledge latency (cycles after the request)");
    req("REG-1.2");
    reg_read(tx_addr(COMMON, 16#FC#), d, ok, lat);
    check(not ok, "undefined TX register: no read acknowledge");
    reg_read(tx_addr(BROADCAST, C_ADDR_TX_UART_CONFIG), d, ok, lat);
    check(not ok, "broadcast channel is write only: no read acknowledge");
    reg_read(x"4004", d, ok, lat);
    check(not ok, "RX scope: no read acknowledge from TX");
    reg_read(x"F020", d, ok, lat);
    check(not ok, "global scope: no read acknowledge from TX");
    req("REG-2.1");
    reg_write(tx_addr(3, C_ADDR_TX_UART_CONFIG), x"00010004");
    check_reg(tx_addr(3, C_ADDR_TX_UART_CONFIG), x"00010004", "UART_CONFIG ch3 read back");
    req("REG-2.2");
    check_reg(tx_addr(4, C_ADDR_TX_UART_CONFIG), x"00000006", "UART_CONFIG ch4 untouched");
    req("REG-2.3");
    reg_write(tx_addr(BROADCAST, C_ADDR_TX_UART_CONFIG), x"00000005");
    check_reg(tx_addr(0,  C_ADDR_TX_UART_CONFIG), x"00000005", "broadcast reaches ch0");
    check_reg(tx_addr(3,  C_ADDR_TX_UART_CONFIG), x"00000005", "broadcast reaches ch3");
    check_reg(tx_addr(39, C_ADDR_TX_UART_CONFIG), x"00000005", "broadcast reaches ch39");
    reg_write(tx_addr(BROADCAST, C_ADDR_TX_UART_CONFIG), x"00000006");
    req("REG-4.1");
    check(tready = '1', "stream ready when idle");
    check(posi = (posi'range => '1'), "all POSI lines idle high");

    ---------------------------------------------------------------------
    print("-- one packet: masked channels transmit their word, the others stay idle");
    req("TX-1.1");
    snapshot;
    mask := (others => '0');
    mask(0) := '1';
    mask(5) := '1';
    mask(39) := '1';
    packet(mask, 1);
    wait_idle;
    for c in 0 to C_NUM_UART-1 loop
      if mask(c) = '1' then
        check_frames(c, 1, "one packet");
        check_word(c, n0(c), word(c, 1), "one packet");
      else
        check_frames(c, 0, "one packet");
      end if;
    end loop;
    req("TX-2.1");
    check_equal(bad_stop(0) + bad_stop(5) + bad_stop(39), 0, "stop bits high");
    -- all masked channels start together (same phase config)
    check_equal(rx_start(5, n0(5)), rx_start(0, n0(0)), "channels 0 and 5 start together");
    check_equal(rx_start(39, n0(39)), rx_start(0, n0(0)), "channels 0 and 39 start together");

    print("-- frame timing: start bit + 64 data bits = 650 cycles, then the stop bit");
    req("TX-2.1");
    t := rx_end(0, n0(0)) - rx_start(0, n0(0));   -- +-1: the decoder samples mid bit
    check(t >= 649 and t <= 651, "start of start bit to start of stop bit: " & integer'image(t) & " cycles (650)");

    print("-- status registers:  UART status (state bits 5:4, line bit 1) and buffer status (state bits 9:8)");
    req("TX-3.3");
    reg_read(tx_addr(0, C_ADDR_TX_UART_STATUS), d, ok, lat);
    check(ok, "UART 0 status acknowledged");
    check_equal(d(5 downto 4), "00", "UART 0 idle:  state IDLE");
    check_equal(d(1), '1', "UART 0 idle:  line high");
    reg_read(tx_addr(COMMON, C_ADDR_TX_BUFFER_STATUS), d, ok, lat);
    check(ok, "buffer status acknowledged");
    check_equal(d(9 downto 8), "00", "buffer idle:  state IDLE");
    mask := (others => '0');
    mask(2) := '1';
    packet(mask, 7);
    wait for 2 us;                                -- inside the 650-cycle frame
    reg_read(tx_addr(2, C_ADDR_TX_UART_STATUS), d, ok, lat);
    check_equal(d(5 downto 4), "01", "UART 2 mid-frame:  state SHIFT");
    reg_read(tx_addr(3, C_ADDR_TX_UART_STATUS), d, ok, lat);
    check_equal(d(5 downto 4), "00", "UART 3 (not in the mask):  state IDLE");
    check_equal(d(1), '1', "UART 3:  line high");
    reg_read(tx_addr(COMMON, C_ADDR_TX_BUFFER_STATUS), d, ok, lat);
    check_equal(d(9 downto 8), "00", "buffer back to IDLE once UART 2 took its word");
    wait_idle;
    reg_read(tx_addr(2, C_ADDR_TX_UART_STATUS), d, ok, lat);
    check_equal(d(5 downto 4), "00", "UART 2 after the frame:  state IDLE");

    print("-- every channel at once, all distinct words");
    req("TX-1.2");
    snapshot;
    mask := x"000000FFFFFFFFFF";
    packet(mask, 2);
    wait_idle;
    for c in 0 to C_NUM_UART-1 loop
      check_frames(c, 1, "all channels");
      check_word(c, n0(c), word(c, 2), "all channels");
    end loop;

    print("-- mask bits above 39 are ignored");
    req("TX-1.1");
    snapshot;
    packet(x"FFFFFF0000000000", 3);
    wait_idle;
    for c in 0 to C_NUM_UART-1 loop
      check_frames(c, 0, "upper mask bits only");
    end loop;

    print("-- back-to-back packets: the next packet is read while the UARTs send, frames follow in order");
    req("TX-1.3");
    snapshot;
    mask := (others => '0');
    mask(7) := '1';
    mask(8) := '1';
    packet(mask, 4);
    packet(mask, 5);            -- accepted while packet 4 is still being sent
    t := cycle;
    mask(8) := '0';
    packet(mask, 6);            -- waits until packet 4's words are all taken
    wait_idle;
    check_frames(7, 3, "back to back");
    check_frames(8, 2, "back to back");
    check_word(7, n0(7),     word(7, 4), "back to back");
    check_word(7, n0(7) + 1, word(7, 5), "back to back");
    check_word(7, n0(7) + 2, word(7, 6), "back to back");
    check_word(8, n0(8),     word(8, 4), "back to back");
    check_word(8, n0(8) + 1, word(8, 5), "back to back");
    -- with DELAY 0 the next start bit follows one stop bit
    req("TX-2.1");
    check_equal(rx_start(7, n0(7) + 1) - rx_start(7, n0(7)), 660, "frame period with DELAY 0 (cycles)");
    check_equal(rx_start(7, n0(7) + 2) - rx_start(7, n0(7) + 1), 660, "frame period, third packet");

    print("-- DELAY (UART_CONFIG bits 31:16, in bit periods) between frames");
    req("TX-2.2");
    reg_write(tx_addr(9, C_ADDR_TX_UART_CONFIG), x"00050006");
    snapshot;
    mask := (others => '0');
    mask(9) := '1';
    mask(10) := '1';
    packet(mask, 7);
    packet(mask, 8);
    wait_idle;
    check_word(9, n0(9) + 1, word(9, 8), "delay 5");
    -- DELAY d adds exactly d bit periods after the stop bit (10 cycles per bit)
    check_equal(rx_start(9, n0(9) + 1) - rx_start(9, n0(9)), 660 + 50, "frame period with DELAY 5 (cycles)");
    check_equal(rx_start(10, n0(10) + 1) - rx_start(10, n0(10)), 660, "channel 10 (DELAY 0) unaffected");
    reg_write(tx_addr(9, C_ADDR_TX_UART_CONFIG), x"00010006");
    snapshot;
    packet(mask, 9);
    packet(mask, 10);
    wait_idle;
    check_word(9, n0(9) + 1, word(9, 10), "delay 1");
    check_equal(rx_start(9, n0(9) + 1) - rx_start(9, n0(9)), 660 + 10, "frame period with DELAY 1 (cycles)");
    reg_write(tx_addr(9, C_ADDR_TX_UART_CONFIG), x"00000006");

    print("-- PHASE (bits 7:0) moves the bit edges within the BAUD period");
    req("TX-2.3");
    reg_write(tx_addr(11, C_ADDR_TX_UART_CONFIG), x"00000002");
    snapshot;
    mask := (others => '0');
    mask(11) := '1';
    mask(12) := '1';
    packet(mask, 9);
    wait_idle;
    check_word(11, n0(11), word(11, 9), "phase 2");
    -- (the two may start in different BAUD periods: compare within the period)
    check_equal((rx_start(12, n0(12)) - rx_start(11, n0(11)) + 100) mod 10, 4,
                "phase 6 edges 4 cycles after phase 2 edges (mod 10)");
    reg_write(tx_addr(11, C_ADDR_TX_UART_CONFIG), x"00000006");

    ---------------------------------------------------------------------
    -- standing check (Michael): BEATS counts the valid/ready handshakes,
    -- STARTS the frames the channel began; a mismatch would mean VALID
    -- dropped during a transfer.  All traffic since reset, every channel.
    print("-- counters: STARTS = BEATS on every channel after all traffic so far");
    req("TX-3.1");
    t := 0;
    for c in 0 to C_NUM_UART-1 loop
      reg_read(tx_addr(c, C_ADDR_TX_UART_STARTS), d, ok, lat);
      check(ok, "STARTS ch" & integer'image(c) & " acknowledged");
      w(31 downto 0) := d;
      reg_read(tx_addr(c, C_ADDR_TX_UART_BEATS), d, ok, lat);
      check(ok, "BEATS ch" & integer'image(c) & " acknowledged");
      check_equal(d, w(31 downto 0), "BEATS = STARTS on ch" & integer'image(c));
      if unsigned(d) /= 0 then
        t := t + 1;
      end if;
    end loop;
    print("   " & integer'image(t) & " channels with traffic, all STARTS = BEATS");
    check(t >= 8, "STARTS = BEATS check saw traffic on several channels");

    print("-- counters: STARTS and BEATS count frames handed to each channel");
    req("TX-3.1");
    reg_write(tx_addr(COMMON, C_ADDR_TX_ZERO_CNTS), x"00000000");
    wait for 100 ns;
    check_reg(tx_addr(7, C_ADDR_TX_UART_STARTS), x"00000000", "STARTS ch7 after ZERO_CNTS");
    check_reg(tx_addr(7, C_ADDR_TX_UART_BEATS),  x"00000000", "BEATS ch7 after ZERO_CNTS");
    mask := (others => '0');
    mask(7) := '1';
    packet(mask, 10);
    packet(mask, 11);
    wait_idle;
    wait for 100 ns;
    check_reg(tx_addr(7, C_ADDR_TX_UART_STARTS), x"00000002", "STARTS ch7 after 2 frames");
    check_reg(tx_addr(7, C_ADDR_TX_UART_BEATS),  x"00000002", "BEATS ch7 after 2 frames");
    check_reg(tx_addr(6, C_ADDR_TX_UART_STARTS), x"00000000", "STARTS ch6 untouched");

    print("-- LOOK registers: the word last loaded for the selected channel");
    req("TX-3.2");
    reg_write(tx_addr(COMMON, C_ADDR_TX_LOOK_SELECT), x"00000007");
    check_reg(tx_addr(COMMON, C_ADDR_TX_LOOK_SELECT), x"00000007", "LOOK_SELECT read back");
    w := word(7, 11);
    check_reg(tx_addr(COMMON, C_ADDR_TX_LOOK_LOWER), w(31 downto 0),  "LOOK_LOWER (ch7)");
    check_reg(tx_addr(COMMON, C_ADDR_TX_LOOK_UPPER), w(63 downto 32), "LOOK_UPPER (ch7)");

    print("-- reset restores the defaults");
    req("REG-4.1");
    reg_write(tx_addr(2, C_ADDR_TX_UART_CONFIG), x"12340001");
    wait until falling_edge(clk);
    rst <= '1';
    wait for 5 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 5 * PERIOD;
    check_reg(tx_addr(2, C_ADDR_TX_UART_CONFIG), x"00000006", "UART_CONFIG ch2 after reset");
    check_reg(tx_addr(7, C_ADDR_TX_UART_STARTS), x"00000000", "STARTS ch7 after reset");

    finish("tx_unit_check");
    done <= true;
    wait;
  end process;
end behaviour;

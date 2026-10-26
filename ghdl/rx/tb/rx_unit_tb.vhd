----------------------------------------------------------------------------------------------------
-- rx_unit_tb: the whole RX unit, configured over the regbus.
--
-- Default scenario: Every UART is fed simulated RX data, and the resulting stream is shown for two
-- cycles.  The status is then read showing two starts, beats, and updates with none lost.
--
-- (Alternative scenarios are in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_utils.all;

entity rx_unit_tb is
end rx_unit_tb;

architecture behaviour of rx_unit_tb is
  signal timestamp : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0) := (others => '0');
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal uclk      : std_logic;
  signal baud      : std_logic;

  signal tdata     : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0) := (others => '0');
  signal tvalid    : std_logic;
  signal tready    : std_logic := '1';
  signal tlast     : std_logic;

  signal rb        : rb_t := RB_IDLE;
  signal rbr       : rbr_t;

  signal piso      : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '0');
  signal rx        : std_logic := '1';
  signal show_axis : boolean := false;
begin
  uut: entity work.rx_unit port map (
    ACLK                => clk,
    RST_I               => rst,
    BAUD_I              => baud,
    M_AXIS_TDATA        => tdata,
    M_AXIS_TVALID       => tvalid,
    M_AXIS_TREADY       => tready,
    M_AXIS_TLAST        => tlast,
    S_REGBUS_RB_RUPDATE => rb.rupdate,
    S_REGBUS_RB_RADDR   => rb.raddr,
    S_REGBUS_RB_RDATA   => rbr.rdata,
    S_REGBUS_RB_RACK    => rbr.rack,
    S_REGBUS_RB_WUPDATE => rb.wupdate,
    S_REGBUS_RB_WADDR   => rb.waddr,
    S_REGBUS_RB_WDATA   => rb.wdata,
    S_REGBUS_RB_WACK    => rbr.wack,
    TIMESTAMP_I         => timestamp,
    RX_MARKER_I         => x"0",
    FIFO_COUNT_I        => x"CCCCCCCC",
    PISO_I              => piso,
    PISO_SYNC_O         => open,
    LOOPBACK_I          => piso,
    STATUS_O            => open,
    M_AXIS_TKEEP        => open
  );

  clk_process : process
  begin
    count <= count + 1;
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  rst_process : process
  begin
    rst <= '1';
    wait for 10 ns;
    rst <= '0';
    wait;
  end process;

  uclk_process : process
  begin
    uclk <= '1';
    wait for 50 ns;
    uclk <= '0';
    wait for 50 ns;
  end process;

  baud_process : process
  begin
    baud <= '1';
    wait for 10 ns;
    baud <= '0';
    wait for 90 ns;
  end process;

  timestamp_process : process
  begin
    timestamp <= x"0000000000000123";
    --choose valid just in time, or one frag too late...
    --test protection against mid-word valid.
    --wait until count=958;
    wait until count=959;
    timestamp <= x"0000000000000ABC";
    wait;
  end process;

  regbus_process : process
    -- RX registers:  chan 0-39 (one UART), C_CHAN_BROADCAST (write all UARTs), C_CHAN_GLOBAL
    procedure wr(chan, reg : integer; d : std_logic_vector; txt : string) is
    begin reg_write(clk, rb, rbr, addr(C_SCOPE_UPPER_RX, chan, reg), d, txt); end procedure;
    procedure rd(chan, reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, addr(C_SCOPE_UPPER_RX, chan, reg), txt); end procedure;
    constant G : integer := C_CHAN_GLOBAL;
  begin
    wait until rst = '0';
    wait until rising_edge(clk);

    wr(C_CHAN_BROADCAST, C_ADDR_RX_UART_CONFIG, x"000A1104",
       "all UARTs:  period 0A, edge mode, PISO input, phase 4");
    wr(G, C_ADDR_RX_BUFFER_CONFIG,    x"00000001", "buffer:  timeout 1, no max words");
    wr(G, C_ADDR_RX_BUFFER_ENABLES,   x"00000000",
       "enables:  no extra channels (heartbeat, rollover, markers off)");
    wr(G, C_ADDR_RX_PACMAN,           x"000000AB", "PACMAN id");
    wr(G, C_ADDR_RX_HEARTBEAT_CONFIG, x"00000001", "heartbeat config");
    wr(G, C_ADDR_RX_ROLLOVER_CONFIG,  x"00000ABC", "rollover config");
    wr(G, C_ADDR_RX_WORD_TYPE_LUT,    x"43434445", "word type LUT");
    rd(0, C_ADDR_RX_UART_STATUS,     "UART 0 status");
    rd(G, C_ADDR_RX_BUFFER_STATUS,   "buffer status");
    rd(0, C_ADDR_RX_UART_CONFIG,     "UART 0 config");

    -- test pattern:
    --wr(G, C_ADDR_RX_PATTERN_A,        x"CCCCDDDD", "pattern payload A");
    --wr(G, C_ADDR_RX_PATTERN_B,        x"AAAABBBB", "pattern payload B");
    --wr(G, C_ADDR_RX_PATTERN_CONFIG,   x"00000101", "pattern on, phase 1");
    --wr(C_CHAN_BROADCAST, C_ADDR_RX_UART_CONFIG, x"000A1404", "all UARTs:  period 0A, edge mode, pattern input, phase 4");

    -- alternative settings:
    --wr(C_CHAN_BROADCAST, C_ADDR_RX_UART_CONFIG, x"000A0404", "all UARTs:  mode 0 (off)");
    --wr(5, C_ADDR_RX_UART_CONFIG, x"000A1104", "UART chan 6 only");
    --wr(G, C_ADDR_RX_BUFFER_ENABLES,   x"00000002", "enables:  rollover");
    --wr(G, C_ADDR_RX_BUFFER_CONFIG,    x"00030001", "buffer:  timeout 1, at most 3 words per packet");

    note("AXI stream out (beats only):");
    show_axis <= true;
    wait until count = 2000;
    show_axis <= false;
    note("at 20 us:");
    rd(0, C_ADDR_RX_UART_STATUS,     "UART 0 status");
    rd(G, C_ADDR_RX_BUFFER_STATUS,   "buffer status");
    rd(G, C_ADDR_RX_LOOK_UA,         "look A (UART 0)");
    rd(G, C_ADDR_RX_LOOK_UB,         "look B (UART 0)");
    rd(0, C_ADDR_RX_UART_STARTS,     "UART 0 starts");
    rd(0, C_ADDR_RX_UART_BEATS,      "UART 0 beats");
    rd(0, C_ADDR_RX_UART_UPDATES,    "UART 0 updates");
    rd(0, C_ADDR_RX_UART_LOST,       "UART 0 lost");
    rd(G, C_ADDR_RX_FIFO_CNT,        "FIFO count");
    rd(G, C_ADDR_RX_FIFO_MAX,        "FIFO max");
    rd(G, C_ADDR_RX_PATTERN_CONFIG,  "pattern config");
    rd(G, C_ADDR_RX_PATTERN_STARTS,  "pattern starts");
    wait;
  end process;

  -- one line per 192-bit word (three beats:  header, timestamp, data):
  -- header = channel (16 bits) | PACMAN id | word type;  the trailer (TLAST) carries the word count
  axis_output_process : process
    variable h, t : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0);
    variable f    : integer := 0;
  begin
    wait until rising_edge(clk);
    wait for 1 ns;
    if (tvalid = '1') and (tready = '1') then
      if f = 0 then h := tdata; end if;
      if f = 1 then t := tdata; end if;
      if f = 2 and show_axis then
        strip(count, "ch " & hex(h(31 downto 16)) & " id " & hex(h(15 downto 8)) & " type " & hex(h(7 downto 0))
              & " | t " & hex(t) & " | d " & hex(tdata) & mark(tlast, "(TLAST)") & mark(rst, "(RESET)"));
      end if;
      f := (f + 1) mod 3;
    end if;
  end process;

  piso(C_NUM_UART-1 downto 0) <= (others => rx);

  -- PISO stimulus (not selected while the UARTs are on the pattern input)
  rx_process : process
    constant rxdata : std_logic_vector(159 downto 0) := x"FF33332222000011117FFF33331111000011117F";
  begin
    wait for 20 ns;
    for i in 0 to 159 loop
      wait until rising_edge(uclk);
      wait for 1 ns;
      rx <= rxdata(i);
    end loop;
    wait until rising_edge(uclk);
    wait for 1 ns;
    rx <= '1';
    wait;
  end process;
end behaviour;

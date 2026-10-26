----------------------------------------------------------------------------------------------------
-- rx_registers_tb:  RX register file test bench
--
-- Shows one line per register access (W writes, R reads) and output lines
-- showing how the modules output registers are driven.
--
-- Scenario: the inputs stand in for the rest of the RX unit:  UART status (the UART number in bits
-- 31-24, events pulsed on bits 2-8), the FIFO count, the pattern status, the buffer status
-- (AAAABBBB) and the look data (the select, in both halves:  BBBBBBss AAAAAAss)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_utils.all;

entity rx_registers_tb is
end rx_registers_tb;

architecture behaviour of rx_registers_tb is
  signal count      : integer := 0;
  signal clk        : std_logic;
  signal rst        : std_logic;
  signal rb         : rb_t := RB_IDLE;
  signal rbr        : rbr_t;

  -- inputs
  signal ustatus    : uart_reg_array_t;
  signal fifo_count : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := x"00000000";
  signal pstatus    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := x"5A000000";
  signal look_data  : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0);

  -- outputs
  signal uart_config                  : uart_reg_array_t;
  signal uart_chan                    : uart_small_array_t;
  signal bconfig, benables, pacman    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal hb_config, ro_config, wlut   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal hdr_a, hdr_b, hdr_c, hdr_d   : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal hdr_eop                      : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal look_select                  : std_logic_vector(C_SELECT_WIDTH-1 downto 0);
  signal p_payload                    : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  signal p_delay, p_config            : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  constant G  : integer := C_CHAN_GLOBAL;
  constant BC : integer := C_CHAN_BROADCAST;
  function rx(chan, reg : integer) return std_logic_vector is
  begin return addr(C_SCOPE_UPPER_RX, chan, reg); end function;

  function init_status return uart_reg_array_t is
    variable s : uart_reg_array_t;
  begin
    for u in s'range loop s(u) := std_logic_vector(to_unsigned(u, 8)) & x"000000"; end loop;
    return s;
  end function;
begin
  uut0: entity work.rx_registers port map (
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
    UART_STATUS_I       => ustatus,
    UART_CONFIG_O       => uart_config,
    UART_CHAN_O         => uart_chan,
    BUFFER_STATUS_I     => x"AAAABBBB",
    FIFO_COUNT_I        => fifo_count,
    BUFFER_CONFIG_O     => bconfig,
    BUFFER_ENABLES_O    => benables,
    PACMAN_O            => pacman,
    HEARTBEAT_CONFIG_O  => hb_config,
    ROLLOVER_CONFIG_O   => ro_config,
    WORD_TYPE_LUT_O     => wlut,
    HEADER_A_O          => hdr_a,
    HEADER_B_O          => hdr_b,
    HEADER_C_O          => hdr_c,
    HEADER_D_O          => hdr_d,
    EOP_HEADER_O        => hdr_eop,
    LOOK_SELECT_O       => look_select,
    LOOK_UART_DATA_I    => look_data,
    PATTERN_STATUS_I    => pstatus,
    PATTERN_PAYLOAD_O   => p_payload,
    PATTERN_DELAY_O     => p_delay,
    PATTERN_CONFIG_O    => p_config
  );

  -- the selected UART's word, as the RX unit would supply it
  look_data <= x"BBBBBB" & "00" & look_select & x"AAAAAA" & "00" & look_select;

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
    procedure wr(chan, reg : integer; d : std_logic_vector; txt : string) is
    begin reg_write(clk, rb, rbr, rx(chan, reg), d, txt); end procedure;
    procedure rd(chan, reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, rx(chan, reg), txt); end procedure;
    procedure tick(n : integer := 1) is
    begin
      for i in 1 to n loop wait until rising_edge(clk); end loop;
      wait for 1 ns;
    end procedure;
    procedure outputs(s : string) is            -- one clock later:  UART config has an extra stage
    begin tick; strip(count, "outputs:  " & s); end procedure;
    -- n events on UART u:  the status bits in mask high for one clock, then low for one
    procedure events(u : integer; mask : std_logic_vector(31 downto 0); n : integer) is
      variable s : std_logic_vector(31 downto 0);
    begin
      s := ustatus(u);
      for i in 1 to n loop
        ustatus(u) <= s or mask; tick;
        ustatus(u) <= s;         tick;
      end loop;
    end procedure;
    constant EV_VALID  : std_logic_vector(31 downto 0) := x"00000004";
    constant EV_READY  : std_logic_vector(31 downto 0) := x"00000008";
    constant EV_START  : std_logic_vector(31 downto 0) := x"00000010";
    constant EV_UPDATE : std_logic_vector(31 downto 0) := x"00000020";
    constant EV_LOST   : std_logic_vector(31 downto 0) := x"00000040";
    constant EV_FRAME  : std_logic_vector(31 downto 0) := x"00000080";
    constant EV_NOISE  : std_logic_vector(31 downto 0) := x"00000100";
    procedure counters(u : integer) is
    begin
      rd(u, C_ADDR_RX_UART_STARTS,    "UART " & dec(u) & " starts");
      rd(u, C_ADDR_RX_UART_BEATS,     "UART " & dec(u) & " beats");
      rd(u, C_ADDR_RX_UART_UPDATES,   "UART " & dec(u) & " updates");
      rd(u, C_ADDR_RX_UART_LOST,      "UART " & dec(u) & " lost");
      rd(u, C_ADDR_RX_UART_FRAME_ERR, "UART " & dec(u) & " frame errors");
      rd(u, C_ADDR_RX_UART_NOISE,     "UART " & dec(u) & " noise");
    end procedure;
  begin
    ustatus <= init_status;
    wait until rst = '0';
    tick;

    note("UART config and channel id, after reset (channel id:  UART number + 1)");
    rd(0,  C_ADDR_RX_UART_CONFIG, "UART 0 config");
    rd(39, C_ADDR_RX_UART_CONFIG, "UART 39 config");
    rd(0,  C_ADDR_RX_UART_CHAN,   "UART 0 channel id");
    rd(39, C_ADDR_RX_UART_CHAN,   "UART 39 channel id");
    note("UART config:  broadcast to every UART, then UART 1 alone");
    wr(BC, C_ADDR_RX_UART_CONFIG, x"00001002", "all UARTs:  config");
    wr(1,  C_ADDR_RX_UART_CONFIG, x"00001001", "UART 1:  config");
    rd(0,  C_ADDR_RX_UART_CONFIG, "UART 0 config");
    rd(1,  C_ADDR_RX_UART_CONFIG, "UART 1 config");
    rd(39, C_ADDR_RX_UART_CONFIG, "UART 39 config");
    outputs("UART config 0 " & hex(uart_config(0)) & " | 1 " & hex(uart_config(1))
            & " | 39 " & hex(uart_config(39)));
    note("channel id:  16 bits, one UART at a time (no broadcast)");
    wr(1,  C_ADDR_RX_UART_CHAN, x"ABCD1234", "UART 1:  channel id");
    rd(1,  C_ADDR_RX_UART_CHAN, "UART 1 channel id:  the low 16 bits");
    wr(BC, C_ADDR_RX_UART_CHAN, x"00005555", "all UARTs:  channel id");
    outputs("channel id 0 " & hex(uart_chan(0)) & " | 1 " & hex(uart_chan(1))
            & " | 39 " & hex(uart_chan(39)));

    note("UART status:  the input as it is (UART number in bits 31-24)");
    rd(0,  C_ADDR_RX_UART_STATUS, "UART 0 status");
    rd(12, C_ADDR_RX_UART_STATUS, "UART 12 status");
    rd(39, C_ADDR_RX_UART_STATUS, "UART 39 status");

    note("counters, UART 12:  1 start, 2 beats (valid and ready), 3 updates, 4 lost, 5 frame"
         & " errors, 6 noise;  then 7 valid without ready (not beats)");
    events(12, EV_START, 1);
    events(12, EV_VALID or EV_READY, 2);
    events(12, EV_UPDATE, 3);
    events(12, EV_LOST, 4);
    events(12, EV_FRAME, 5);
    events(12, EV_NOISE, 6);
    events(12, EV_VALID, 7);
    counters(12);
    rd(11, C_ADDR_RX_UART_STARTS, "UART 11 starts:  its neighbour's events are not its own");

    note("FIFO count:  5, 100 for one clock, then 10;  the maximum keeps the peak");
    fifo_count <= x"00000005"; tick(5);
    fifo_count <= x"00000064"; tick;
    fifo_count <= x"0000000A"; tick(5);
    rd(G, C_ADDR_RX_FIFO_CNT, "FIFO count");
    rd(G, C_ADDR_RX_FIFO_MAX, "FIFO maximum");

    note("pattern:  status input 5A000000;  3 starts (bit 0) and 2 stops (bit 1)");
    for i in 1 to 3 loop pstatus <= x"5A000001"; tick; pstatus <= x"5A000000"; tick; end loop;
    for i in 1 to 2 loop pstatus <= x"5A000002"; tick; pstatus <= x"5A000000"; tick; end loop;
    tick(3);
    rd(G, C_ADDR_RX_PATTERN_STATUS, "pattern status");
    rd(G, C_ADDR_RX_PATTERN_STARTS, "pattern starts");
    rd(G, C_ADDR_RX_PATTERN_STOPS,  "pattern stops");
    wr(G, C_ADDR_RX_PATTERN_A,      x"AAAAAAAA", "pattern payload, low word");
    wr(G, C_ADDR_RX_PATTERN_B,      x"BBBBBBBB", "pattern payload, high word");
    wr(G, C_ADDR_RX_PATTERN_DELAY,  x"00000002", "pattern delay");
    wr(G, C_ADDR_RX_PATTERN_CONFIG, x"00000001", "pattern config");
    rd(G, C_ADDR_RX_PATTERN_A,      "pattern payload, low word");
    rd(G, C_ADDR_RX_PATTERN_B,      "pattern payload, high word");
    rd(G, C_ADDR_RX_PATTERN_DELAY,  "pattern delay");
    rd(G, C_ADDR_RX_PATTERN_CONFIG, "pattern config");
    outputs("pattern payload " & hex(p_payload) & " | delay " & hex(p_delay)
            & " | config " & hex(p_config));

    note("ZERO_CNTS:  every counter, the pattern counters and the FIFO maximum (count still 10)");
    wr(G, C_ADDR_RX_ZERO_CNTS, x"00000000", "zero counters");
    rd(12, C_ADDR_RX_UART_STARTS, "UART 12 starts, right after:  the old count (two stages)");
    counters(12);
    rd(G, C_ADDR_RX_PATTERN_STARTS, "pattern starts");
    rd(G, C_ADDR_RX_PATTERN_STOPS,  "pattern stops");
    rd(G, C_ADDR_RX_FIFO_MAX,       "FIFO maximum:  restarts from the count");

    note("buffer and packet registers, after reset");
    rd(G, C_ADDR_RX_BUFFER_STATUS,    "buffer status (input AAAABBBB)");
    rd(G, C_ADDR_RX_BUFFER_CONFIG,    "buffer config");
    rd(G, C_ADDR_RX_BUFFER_ENABLES,   "buffer enables");
    rd(G, C_ADDR_RX_PACMAN,           "PACMAN id");
    rd(G, C_ADDR_RX_WORD_TYPE_LUT,    "word type LUT");
    rd(G, C_ADDR_RX_HEARTBEAT_CONFIG, "heartbeat config");
    rd(G, C_ADDR_RX_ROLLOVER_CONFIG,  "rollover config");
    rd(G, C_ADDR_RX_HEADER_A,         "header A (heartbeat)");
    rd(G, C_ADDR_RX_HEADER_B,         "header B (rollover)");
    rd(G, C_ADDR_RX_HEADER_C,         "header C (trigger)");
    rd(G, C_ADDR_RX_HEADER_D,         "header D");
    rd(G, C_ADDR_RX_EOP_HEADER,       "end-of-packet header");
    note("written, read back");
    wr(G, C_ADDR_RX_BUFFER_CONFIG,    x"00000C42", "buffer config");
    wr(G, C_ADDR_RX_BUFFER_ENABLES,   x"0000000F", "buffer enables");
    wr(G, C_ADDR_RX_WORD_TYPE_LUT,    x"76543210", "word type LUT");
    wr(G, C_ADDR_RX_HEARTBEAT_CONFIG, x"00001000", "heartbeat config");
    wr(G, C_ADDR_RX_ROLLOVER_CONFIG,  x"00000003", "rollover config");
    rd(G, C_ADDR_RX_BUFFER_CONFIG,    "buffer config");
    rd(G, C_ADDR_RX_BUFFER_ENABLES,   "buffer enables");
    rd(G, C_ADDR_RX_WORD_TYPE_LUT,    "word type LUT");
    rd(G, C_ADDR_RX_HEARTBEAT_CONFIG, "heartbeat config");
    rd(G, C_ADDR_RX_ROLLOVER_CONFIG,  "rollover config");
    outputs("buffer config " & hex(bconfig) & " | enables " & hex(benables) & " | LUT " & hex(wlut)
            & " | heartbeat " & hex(hb_config) & " | rollover " & hex(ro_config));
    note("headers:  the PACMAN id goes into bits 15-8 of each header out, not into the registers");
    wr(G, C_ADDR_RX_HEADER_D,   x"11223344", "header D");
    rd(G, C_ADDR_RX_HEADER_D,   "header D");
    outputs("headers A " & hex(hdr_a) & " | B " & hex(hdr_b) & " | C " & hex(hdr_c)
            & " | D " & hex(hdr_d) & " | EOP " & hex(hdr_eop));
    wr(G, C_ADDR_RX_PACMAN,     x"000000AB", "PACMAN id");
    rd(G, C_ADDR_RX_PACMAN,     "PACMAN id");
    rd(G, C_ADDR_RX_HEADER_D,   "header D");
    outputs("headers A " & hex(hdr_a) & " | B " & hex(hdr_b) & " | C " & hex(hdr_c)
            & " | D " & hex(hdr_d) & " | EOP " & hex(hdr_eop));

    note("look:  select a UART (6 bits kept), its word in look A and B");
    rd(G, C_ADDR_RX_LOOK_SELECT, "look select");
    rd(G, C_ADDR_RX_LOOK_UA,     "look A");
    wr(G, C_ADDR_RX_LOOK_SELECT, x"FFFFFFE7", "look select:  UART 39");
    rd(G, C_ADDR_RX_LOOK_SELECT, "look select");
    rd(G, C_ADDR_RX_LOOK_UA,     "look A");
    rd(G, C_ADDR_RX_LOOK_UB,     "look B");

    note("no ack:  read-only and write-only registers the wrong way, addresses not RX registers");
    wr(G,  C_ADDR_RX_BUFFER_STATUS, x"FFFFFFFF", "buffer status");
    wr(12, C_ADDR_RX_UART_STARTS,   x"FFFFFFFF", "UART 12 starts");
    rd(G,  C_ADDR_RX_ZERO_CNTS,     "zero counters");
    rd(BC, C_ADDR_RX_UART_CONFIG,   "broadcast channel, config");
    rd(40, C_ADDR_RX_UART_CONFIG,   "channel 40 (no such UART), config");
    rd(G,  16#FC#,                  "global channel, FC");
    reg_read(clk, rb, rbr, addr(C_SCOPE_UPPER_TX, 0, C_ADDR_RX_UART_CONFIG),
             "TX scope, UART 0 config");
    wait;
  end process;
end behaviour;

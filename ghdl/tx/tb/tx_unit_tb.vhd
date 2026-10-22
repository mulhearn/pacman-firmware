----------------------------------------------------------------------------------------------------
-- tx_unit_tb: the whole TX unit, configured over the regbus.
--
-- Default scenario: one DMA packet (the channel mask, then one word per UART) is sent out on all 40
-- UARTs at once.  The POSI lines are shown bit by bit, UARTs 0 and 39 are decoded, and the counters
-- and look registers are read at the end.
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

entity tx_unit_tb is
end tx_unit_tb;

architecture behaviour of tx_unit_tb is
  signal count  : integer := 0;
  signal clk    : std_logic := '0';
  signal rst    : std_logic := '0';
  signal baud   : std_logic := '0';
  signal tdata  : std_logic_vector(C_TX_AXIS_WIDTH-1 downto 0) := (others => '0');
  signal tvalid : std_logic := '0';
  signal tready : std_logic := '0';
  signal tlast  : std_logic := '0';
  signal rb     : rb_t := RB_IDLE;
  signal rbr    : rbr_t;
  signal posi   : std_logic_vector(C_NUM_UART-1 downto 0);
  signal debug  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  -- the DMA packets sent (alternatives in comments):
  constant MASK    : std_logic_vector(63 downto 0) := x"000000FFFFFFFFFF";  -- channel mask:  all 40 UARTs
  --constant MASK  : std_logic_vector(63 downto 0) := x"000000000000000F";  -- UARTs 0-3 only
  --constant MASK  : std_logic_vector(63 downto 0) := x"0000000000000400";  -- UART 10 only
  constant PACKETS : integer := 1;
  --constant PACKETS : integer := 1;  -- a second packet (words 2222DDxx2222CCxx), back to back
begin
  uut: entity work.tx_unit port map (
    ACLK                => clk,
    RST_I               => rst,
    BAUD_I              => baud,
    S_AXIS_TDATA        => tdata,
    S_AXIS_TVALID       => tvalid,
    S_AXIS_TREADY       => tready,
    S_AXIS_TKEEP        => (others => '1'),
    S_AXIS_TLAST        => tlast,
    S_REGBUS_RB_RUPDATE => rb.rupdate,
    S_REGBUS_RB_RADDR   => rb.raddr,
    S_REGBUS_RB_RDATA   => rbr.rdata,
    S_REGBUS_RB_RACK    => rbr.rack,
    S_REGBUS_RB_WUPDATE => rb.wupdate,
    S_REGBUS_RB_WADDR   => rb.waddr,
    S_REGBUS_RB_WDATA   => rb.wdata,
    S_REGBUS_RB_WACK    => rbr.wack,
    POSI_O              => posi,
    DEBUG_O             => debug
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
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;

  baud_process : process
  begin
    baud <= '1';
    wait for 10 ns;
    baud <= '0';
    wait for 90 ns;
  end process;

  regbus_process : process
    procedure wr(chan, reg : integer; d : std_logic_vector; txt : string) is
    begin reg_write(clk, rb, rbr, addr(C_SCOPE_UPPER_TX, chan, reg), d, txt); end procedure;
    procedure rd(chan, reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, addr(C_SCOPE_UPPER_TX, chan, reg), txt); end procedure;
    constant G : integer := C_CHAN_GLOBAL;
  begin
    wait until rst = '0';
    wr(C_CHAN_BROADCAST, C_ADDR_TX_UART_CONFIG, x"00001601", "all UARTs:  TX config (phase 1)");

    -- alternative settings:
    --wr(C_CHAN_BROADCAST, C_ADDR_TX_UART_CONFIG, x"00020001", "all UARTs:  phase 1, DELAY 2 (with PACKETS = 2)");

    wr(G, C_ADDR_TX_LOOK_SELECT, x"0000000A", "look at UART 10");
    rd(0,  C_ADDR_TX_UART_CONFIG, "UART 0 config");
    rd(12, C_ADDR_TX_UART_CONFIG, "UART 12 config");
    wait for PACKETS * 8 us;
    note("after the transmission:");
    rd(0,  C_ADDR_TX_UART_STARTS, "UART 0 starts");
    rd(12, C_ADDR_TX_UART_STARTS, "UART 12 starts");
    rd(G,  C_ADDR_TX_LOOK_SELECT, "look select");
    rd(G,  C_ADDR_TX_LOOK_UA,     "look A (UART 10)");
    rd(G,  C_ADDR_TX_LOOK_UB,     "look B (UART 10)");
    wait;
  end process;

  stream_process : process
    -- one beat, held until the TX unit takes it
    procedure beat(d : std_logic_vector(C_TX_AXIS_WIDTH-1 downto 0); last : std_logic) is
    begin
      tvalid <= '1';
      tdata  <= d;
      tlast  <= last;
      loop
        wait until rising_edge(clk);
        exit when tready = '1';
      end loop;
      wait for 1 ns;
    end procedure;
    variable w : std_logic_vector(C_TX_AXIS_WIDTH-1 downto 0);
  begin
    wait for 201 ns;
    for p in 0 to PACKETS-1 loop
      note("AXI stream:  41 beats, the channel mask and one word per UART");
      beat(MASK, '0');
      for i in 0 to C_NUM_UART-1 loop
        w := std_logic_vector(to_unsigned(16#1111DD00# + p*16#11110000# + 2*i, 32))
           & std_logic_vector(to_unsigned(16#1111CC00# + p*16#11110000# + 2*i, 32));
        if i = C_NUM_UART-1 then beat(w, '1'); else beat(w, '0'); end if;
      end loop;
    end loop;
    tvalid <= '0';
    tdata  <= (others => '0');
    tlast  <= '0';
    wait;
  end process;

  -- the stream, one line per beat taken at a rising edge (low 16 bits of each half), (TLAST) on the last
  axis_output_process : process
  begin
    wait until rising_edge(clk);
    if tvalid = '1' and tready = '1' then
      strip(count, "tdata " & hex(tdata(63 downto 48)) & "..." & hex(tdata(15 downto 0)) & mark(tlast, "(TLAST)"));
    end if;
  end process;

  -- POSI, one line per baud period;  UARTs 0 and 39 decoded like a UART receiver (start, 64 bits LSB first, stop)
  tx_output_process : process
    type uarts_t is array (0 to 1) of integer;
    constant U    : uarts_t := (0, C_NUM_UART-1);
    type frames_t is array (0 to 1) of std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
    variable fr   : frames_t;
    variable n    : uarts_t := (-1, -1);                       -- bits so far (-1: idle)
  begin
    wait for 600 ns;
    note("POSI (UART 39 ... 0), one line per baud period:");
    fold(true);
    while now < 600 ns + PACKETS * 7200 ns loop
      wait for 100 ns;
      for k in 0 to 1 loop
        if n(k) = -1 and posi(U(k)) = '0' then
          n(k) := 0;
        elsif n(k) >= 0 and n(k) < C_UART_DATA_WIDTH then
          fr(k) := posi(U(k)) & fr(k)(C_UART_DATA_WIDTH-1 downto 1);
          n(k) := n(k) + 1;
        elsif n(k) = C_UART_DATA_WIDTH then
          note("UART " & dec(U(k)) & " sent:  " & hex(fr(k)) & mark(not posi(U(k)), "(no stop bit)"));
          n(k) := -1;
        end if;
      end loop;
      strip(count, "POSI " & hex(posi));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

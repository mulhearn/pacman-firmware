----------------------------------------------------------------------------------------------------
-- tx_registers_tb:  TX register file test bench
--
-- Shows one line per register access (W writes, R reads) and output lines
-- showing how the modules output registers are driven.
--
-- Scenario: the inputs stand in for the rest of the TX unit:  UART status (the UART number in bits
-- 31-24, events pulsed on bits 0, 2 and 3), the buffer status (AAAABBBB) and the look data (the
-- select, in both halves:  BBBBBBss AAAAAAss)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_utils.all;

entity tx_registers_tb is
end tx_registers_tb;

architecture behaviour of tx_registers_tb is
  signal count       : integer := 0;
  signal clk         : std_logic;
  signal rst         : std_logic;
  signal rb          : rb_t := RB_IDLE;
  signal rbr         : rbr_t;

  signal ustatus     : uart_reg_array_t;
  signal look_data   : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0);
  signal uart_config : uart_reg_array_t;
  signal look_select : std_logic_vector(C_SELECT_WIDTH-1 downto 0);

  constant G  : integer := C_CHAN_GLOBAL;
  constant BC : integer := C_CHAN_BROADCAST;
  function tx(chan, reg : integer) return std_logic_vector is
  begin return addr(C_SCOPE_UPPER_TX, chan, reg); end function;

  function init_status return uart_reg_array_t is
    variable s : uart_reg_array_t;
  begin
    for u in s'range loop s(u) := std_logic_vector(to_unsigned(u, 8)) & x"000000"; end loop;
    return s;
  end function;
begin
  uut0: entity work.tx_registers port map (
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
    BUFFER_STATUS_I     => x"AAAABBBB",
    LOOK_SELECT_O       => look_select,
    LOOK_UART_DATA_I    => look_data
  );

  -- the selected UART's word, as the TX unit would supply it
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
    begin reg_write(clk, rb, rbr, tx(chan, reg), d, txt); end procedure;
    procedure rd(chan, reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, tx(chan, reg), txt); end procedure;
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
    constant EV_START : std_logic_vector(31 downto 0) := x"00000001";
    constant EV_VALID : std_logic_vector(31 downto 0) := x"00000004";
    constant EV_READY : std_logic_vector(31 downto 0) := x"00000008";
  begin
    ustatus <= init_status;
    wait until rst = '0';
    tick;

    note("UART config:  after reset, broadcast to every UART, then UART 1 alone");
    rd(0,  C_ADDR_TX_UART_CONFIG, "UART 0 config");
    rd(39, C_ADDR_TX_UART_CONFIG, "UART 39 config");
    wr(BC, C_ADDR_TX_UART_CONFIG, x"00001602", "all UARTs:  config");
    wr(1,  C_ADDR_TX_UART_CONFIG, x"00001601", "UART 1:  config");
    rd(0,  C_ADDR_TX_UART_CONFIG, "UART 0 config");
    rd(1,  C_ADDR_TX_UART_CONFIG, "UART 1 config");
    rd(39, C_ADDR_TX_UART_CONFIG, "UART 39 config");
    outputs("UART config 0 " & hex(uart_config(0)) & " | 1 " & hex(uart_config(1))
            & " | 39 " & hex(uart_config(39)));

    note("UART status:  the input as it is (UART number in bits 31-24)");
    rd(0,  C_ADDR_TX_UART_STATUS, "UART 0 status");
    rd(12, C_ADDR_TX_UART_STATUS, "UART 12 status");
    rd(39, C_ADDR_TX_UART_STATUS, "UART 39 status");

    note("counters, UART 12:  3 starts, 5 beats (valid and ready);  then 7 valid without ready,"
         & " 2 ready without valid (not beats)");
    events(12, EV_START, 3);
    events(12, EV_VALID or EV_READY, 5);
    events(12, EV_VALID, 7);
    events(12, EV_READY, 2);
    rd(12, C_ADDR_TX_UART_STARTS, "UART 12 starts");
    rd(12, C_ADDR_TX_UART_BEATS,  "UART 12 beats");
    rd(11, C_ADDR_TX_UART_STARTS, "UART 11 starts:  its neighbour's events are not its own");

    note("ZERO_CNTS:  both counters, every UART");
    wr(G,  C_ADDR_TX_ZERO_CNTS, x"00000000", "zero counters");
    rd(12, C_ADDR_TX_UART_STARTS, "UART 12 starts, right after:  the old count (two stages)");
    rd(12, C_ADDR_TX_UART_STARTS, "UART 12 starts");
    rd(12, C_ADDR_TX_UART_BEATS,  "UART 12 beats");

    note("buffer status, and look:  select a UART (6 bits kept), its word in look lower and upper");
    rd(G, C_ADDR_TX_BUFFER_STATUS, "buffer status (input AAAABBBB)");
    rd(G, C_ADDR_TX_LOOK_SELECT,   "look select");
    rd(G, C_ADDR_TX_LOOK_LOWER,    "look lower");
    wr(G, C_ADDR_TX_LOOK_SELECT,   x"FFFFFFE7", "look select:  UART 39");
    rd(G, C_ADDR_TX_LOOK_SELECT,   "look select");
    rd(G, C_ADDR_TX_LOOK_LOWER,    "look lower");
    rd(G, C_ADDR_TX_LOOK_UPPER,    "look upper");
    outputs("look select " & hex("00" & look_select));

    note("no ack:  read-only and write-only registers the wrong way, addresses not TX registers");
    wr(G,  C_ADDR_TX_BUFFER_STATUS, x"FFFFFFFF", "buffer status");
    wr(12, C_ADDR_TX_UART_STARTS,   x"FFFFFFFF", "UART 12 starts");
    rd(G,  C_ADDR_TX_ZERO_CNTS,     "zero counters");
    rd(BC, C_ADDR_TX_UART_CONFIG,   "broadcast channel, config");
    rd(40, C_ADDR_TX_UART_CONFIG,   "channel 40 (no such UART), config");
    reg_read(clk, rb, rbr, addr(C_SCOPE_UPPER_RX, 0, C_ADDR_TX_UART_CONFIG),
             "RX scope, UART 0 config");
    wait;
  end process;
end behaviour;

-- rx_registers_check:  the RX counters (STARTS, BEATS, UPDATES, LOST, FRAME_ERR, NOISE, PATTERN_STARTS,
-- PATTERN_STOPS) at the rx_registers ports, built with a small C_COUNT_MAX (20):  held events take them
-- to it, where they stop;  ZERO_CNTS clears them to 0 and they count again.  The status bits drive the counters
-- directly (one count per clock while held), so saturation takes a few clocks.  Stimulus changes on falling clock
-- edges.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity rx_registers_check is
end rx_registers_check;

architecture behaviour of rx_registers_check is
  constant PERIOD : time := 10 ns;
  constant LIMIT  : integer := 20;           -- the saturation value (0xFFFF in the firmware)

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

  signal ustatus : uart_reg_array_t := (others => (others => '0'));
  signal pstatus : std_logic_vector(31 downto 0) := (others => '0');
  signal zero32  : std_logic_vector(31 downto 0) := (others => '0');
  signal zlook   : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0) := (others => '0');

  function rx_addr(chan : integer; reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_UPPER_RX * 16#4000# + chan * 16#100# + reg, 16));
  end function;

  type addr_list_t is array (0 to 5) of integer;
  constant UART_COUNTERS : addr_list_t := (C_ADDR_RX_UART_STARTS, C_ADDR_RX_UART_BEATS, C_ADDR_RX_UART_UPDATES,
                                           C_ADDR_RX_UART_LOST, C_ADDR_RX_UART_FRAME_ERR, C_ADDR_RX_UART_NOISE);
begin
  uut: entity work.rx_registers
    generic map (C_COUNT_MAX => to_unsigned(LIMIT, C_COUNT_BITS))
    port map (
      CLK_I => clk, RST_I => rst,
      S_REGBUS_RB_RUPDATE => rupdate, S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata,
      S_REGBUS_RB_RACK => rack,
      S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr, S_REGBUS_RB_WDATA => wdata,
      S_REGBUS_RB_WACK => wack,
      UART_STATUS_I => ustatus, UART_CONFIG_O => open, UART_CHAN_O => open, BUFFER_STATUS_I => zero32,
      FIFO_COUNT_I => zero32, BUFFER_CONFIG_O => open, BUFFER_ENABLES_O => open, PACMAN_O => open,
      HEARTBEAT_CONFIG_O => open, ROLLOVER_CONFIG_O => open, WORD_TYPE_LUT_O => open, HEADER_A_O => open,
      HEADER_B_O => open, HEADER_C_O => open, HEADER_D_O => open, EOP_HEADER_O => open, LOOK_SELECT_O => open,
      LOOK_UART_DATA_I => zlook, PATTERN_STATUS_I => pstatus, PATTERN_PAYLOAD_O => open, PATTERN_DELAY_O => open,
      PATTERN_CONFIG_O => open);

  clock_until(clk, done, PERIOD);

  test: process
    procedure reg_write(addr : std_logic_vector(15 downto 0); data : std_logic_vector(31 downto 0)) is
    begin
      wait until falling_edge(clk);
      waddr   <= addr;
      wdata   <= data;
      wupdate <= '1';
      wait until falling_edge(clk);
      wupdate <= '0';
      wait for 4 * PERIOD;
    end procedure;

    procedure check_reg(addr : std_logic_vector(15 downto 0); expected : integer; msg : string) is
      variable acked : boolean := false;
    begin
      wait until falling_edge(clk);
      raddr   <= addr;
      rupdate <= '1';
      wait until falling_edge(clk);
      rupdate <= '0';
      for i in 1 to 8 loop
        wait until rising_edge(clk);
        if rack = '1' then
          acked := true;
          check_equal(rdata, std_logic_vector(to_unsigned(expected, 32)), msg);
          exit;
        end if;
      end loop;
      check(acked, msg & ":  acknowledged");
    end procedure;

    -- every counted status bit (VALID, READY, START, UPDATE, LOST, FRAME_ERR, NOISE:  bits 8-2) on every UART,
    -- and the pattern generator's start and stop (bits 1-0), high for n clocks
    procedure events(n : integer) is
    begin
      wait until falling_edge(clk);
      for c in 0 to C_NUM_UART-1 loop
        ustatus(c)(8 downto 2) <= (others => '1');
      end loop;
      pstatus(1 downto 0) <= "11";
      wait for n * PERIOD;
      ustatus <= (others => (others => '0'));
      pstatus <= (others => '0');
      wait for 4 * PERIOD;                 -- counters are registered twice
    end procedure;

    procedure check_counts(expected : integer; msg : string) is
    begin
      for c in 0 to C_NUM_UART-1 loop
        for r in UART_COUNTERS'range loop
          check_reg(rx_addr(c, UART_COUNTERS(r)), expected,
                    msg & ":  UART " & integer'image(c) & " counter 0x" & hex(std_logic_vector(to_unsigned(UART_COUNTERS(r), 8))));
        end loop;
      end loop;
      check_reg(rx_addr(C_CHAN_GLOBAL, C_ADDR_RX_PATTERN_STARTS), expected, msg & ":  PATTERN_STARTS");
      check_reg(rx_addr(C_CHAN_GLOBAL, C_ADDR_RX_PATTERN_STOPS),  expected, msg & ":  PATTERN_STOPS");
    end procedure;
  begin
    wait for 3 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 2 * PERIOD;

    print("-- the counters stop at their saturation value (C_COUNT_MAX 20;  0xFFFF in the firmware)");
    req("RX-6.5");
    check_counts(0, "after reset");
    events(10);
    check_counts(10, "10 events");
    events(10);
    check_counts(LIMIT, "20 more events:  stopped at the saturation value");
    events(100);
    check_counts(LIMIT, "100 more events:  still there, no wrap");

    print("-- ZERO_CNTS clears to 0, and the counters count again;  reset clears to 0");
    req("RX-6.1");
    reg_write(rx_addr(C_CHAN_GLOBAL, C_ADDR_RX_ZERO_CNTS), x"00000000");
    check_counts(0, "ZERO_CNTS");
    events(7);
    check_counts(7, "7 events after ZERO_CNTS");
    req("RX-6.5");
    wait until falling_edge(clk);
    rst <= '1';
    wait for 2 * PERIOD;
    rst <= '0';
    wait for 2 * PERIOD;
    check_counts(0, "after a second reset");

    finish("rx_registers_check");
    done <= true;
    wait;
  end process;
end behaviour;

-- tx_registers_check:  the TX counters (STARTS, BEATS) at the tx_registers ports, built with a small
-- C_COUNT_MAX (20):  held events take them to it, where they stop;  ZERO_CNTS clears them to 0 and they count
-- again.  The status bits drive the counters directly (one count per clock while held), so saturation takes a few
-- clocks.  Stimulus changes on falling clock edges.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_pkg.all;

entity tx_registers_check is
end tx_registers_check;

architecture behaviour of tx_registers_check is
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
  signal zero32  : std_logic_vector(31 downto 0) := (others => '0');
  signal zlook   : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0) := (others => '0');

  function tx_addr(chan : integer; reg : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(C_SCOPE_UPPER_TX * 16#4000# + chan * 16#100# + reg, 16));
  end function;
begin
  uut: entity work.tx_registers
    generic map (C_COUNT_MAX => to_unsigned(LIMIT, C_COUNT_BITS))
    port map (
      CLK_I => clk, RST_I => rst,
      S_REGBUS_RB_RUPDATE => rupdate, S_REGBUS_RB_RADDR => raddr, S_REGBUS_RB_RDATA => rdata,
      S_REGBUS_RB_RACK => rack,
      S_REGBUS_RB_WUPDATE => wupdate, S_REGBUS_RB_WADDR => waddr, S_REGBUS_RB_WDATA => wdata,
      S_REGBUS_RB_WACK => wack,
      UART_STATUS_I => ustatus, UART_CONFIG_O => open, BUFFER_STATUS_I => zero32, LOOK_SELECT_O => open,
      LOOK_UART_DATA_I => zlook);

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

    -- START (bit 0), VALID and READY (bits 2, 3) high on every UART for n clocks
    procedure events(n : integer) is
    begin
      wait until falling_edge(clk);
      for c in 0 to C_NUM_UART-1 loop
        ustatus(c)(0) <= '1';
        ustatus(c)(3 downto 2) <= "11";
      end loop;
      wait for n * PERIOD;
      ustatus <= (others => (others => '0'));
      wait for 4 * PERIOD;                 -- counters are registered twice
    end procedure;

    procedure check_counts(expected : integer; msg : string) is
    begin
      for c in 0 to C_NUM_UART-1 loop
        check_reg(tx_addr(c, C_ADDR_TX_UART_STARTS), expected, msg & ":  STARTS UART " & integer'image(c));
        check_reg(tx_addr(c, C_ADDR_TX_UART_BEATS),  expected, msg & ":  BEATS UART " & integer'image(c));
      end loop;
    end procedure;
  begin
    wait for 3 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait for 2 * PERIOD;

    print("-- the counters stop at their saturation value (C_COUNT_MAX 20;  0xFFFF in the firmware)");
    req("TX-3.4");
    check_counts(0, "after reset");
    events(10);
    check_counts(10, "10 events");
    events(10);
    check_counts(LIMIT, "20 more events:  stopped at the saturation value");
    events(100);
    check_counts(LIMIT, "100 more events:  still there, no wrap");

    print("-- ZERO_CNTS clears to 0, and the counters count again;  reset clears to 0");
    req("TX-3.1");
    reg_write(tx_addr(C_CHAN_GLOBAL, C_ADDR_TX_ZERO_CNTS), x"00000000");
    check_counts(0, "ZERO_CNTS");
    events(7);
    check_counts(7, "7 events after ZERO_CNTS");
    req("TX-3.4");
    wait until falling_edge(clk);
    rst <= '1';
    wait for 2 * PERIOD;
    rst <= '0';
    wait for 2 * PERIOD;
    check_counts(0, "after a second reset");

    finish("tx_registers_check");
    done <= true;
    wait;
  end process;
end behaviour;

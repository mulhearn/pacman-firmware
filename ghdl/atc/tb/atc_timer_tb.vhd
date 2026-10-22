----------------------------------------------------------------------------------------------------
-- atc_timer_tb:  ATC timer test bench
--
-- The UART and BAUD strobes, and the ASIC clock UCLK (50% duty cycle, period = the UART period).
--
-- Shows one line per clock: uart, baud, uclk;  (UART) UART strobe, (BAUD) BAUD strobe.
--
-- Scenario: UART strobe every 4 clocks, BAUD strobe every 8  -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity atc_timer_tb is
end;

architecture behavioral of atc_timer_tb is
  signal count : integer := 0;
  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal uart  : std_logic;
  signal baud  : std_logic;
  signal uclk  : std_logic;
  signal config_uart : std_logic_vector(31 downto 0);
  signal config_baud : std_logic_vector(31 downto 0);
begin
  -- the timer configuration (alternatives in comments):
  config_uart <= x"00000004";                                   -- UART strobe every 4 clocks
  --config_uart <= x"0000000A";                                 -- UART strobe every 10 clocks
  config_baud <= x"00000008";                                   -- BAUD every 8 clocks (UART/2)
  --config_baud <= x"00000004";                                 -- BAUD every 4 clocks (= UART)

  uut: entity work.atc_timer port map (
    CLK_I         => clk,
    RST_I         => rst,
    CONFIG_UART_I => config_uart,
    CONFIG_BAUD_I => config_baud,
    UART_O        => uart,
    BAUD_O        => baud,
    UCLK_O        => uclk
  );

  clk <= not clk after 5 ns;
  rst <= '0' after 21 ns;

  count_process : process
  begin
    wait until rising_edge(clk);
    count <= count + 1;
  end process;

  output_process : process
  begin
    wait for 21 ns;
    loop
      wait for 10 ns;
      strip(count, "uart " & bits(uart) & " baud " & bits(baud) & " uclk " & bits(uclk)
        & mark(uart, "(UART)") & mark(baud, "(BAUD)"));
    end loop;
  end process;
end;

library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;
--  Defines a testbench (without any ports)
entity uart_rx_tb is
end uart_rx_tb;
architecture behaviour of uart_rx_tb is
  component uart_rx is
    generic (
      WIDTH : integer := 64
    );
    port (
      rx_data     : out std_logic_vector(WIDTH-1 downto 0);
      rx_empty    : out std_logic;
      rx_in       : in  std_logic;
      uld_rx_data : in  std_logic;
      clk         : in  std_logic;
      reset_n     : in  std_logic
      );
  end component;
  signal count       : integer := 0;
  signal clk         : std_logic;
  signal reset_n     : std_logic := '0';
  signal rx_in       : std_logic := '1';  -- idle high
  signal uld_rx_data : std_logic := '0';
  signal rx_data     : std_logic_vector(63 downto 0);
  signal rx_empty    : std_logic;

  constant TEST_DATA : std_logic_vector(63 downto 0) := x"5555FFFF00005555";
begin
  uut0: uart_rx port map (
    rx_data     => rx_data,
    rx_empty    => rx_empty,
    rx_in       => rx_in,
    uld_rx_data => uld_rx_data,
    clk         => clk,
    reset_n     => reset_n
  );
  reset_process : process
  begin
    reset_n <= '0';
    wait for 20 ns;
    reset_n <= '1';
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
  stimulus_process : process
  begin
    -- Hold idle through reset
    rx_in <= '1';
    wait for 40 ns;
    -- Start bit (one clock cycle low)
    rx_in <= '0';
    wait for 10 ns;
    -- Data bits LSB-first
    for i in 0 to 63 loop
      rx_in <= TEST_DATA(i);
      wait for 10 ns;
    end loop;
    -- Return to idle
    rx_in <= '1';
    wait for 20 ns;
    -- Pulse uld_rx_data to acknowledge receipt
    uld_rx_data <= '1';
    wait for 10 ns;
    uld_rx_data <= '0';
    wait;
  end process;
  output_process : process
    variable l : line;
  begin
    wait for 10 ns;
    write (l, String'("c: "));
    write (l, count, left, 4);
    write (l, String'(" | rx_in: "));
    write (l, rx_in);
    write (l, String'(" | rx_empty: "));
    write (l, rx_empty);
    write (l, String'(" | rx_data: 0x"));
    hwrite (l, rx_data);
    write (l, String'(" | uld: "));
    write (l, uld_rx_data);
    if (reset_n = '0') then
      write (l, String'(" (RESET)"));
    end if;
    writeline(output, l);
  end process;
  comment_process : process
    variable l : line;
  begin
    wait until (count=4);
    write(l, String'("INFO:  Sending testpattern"));
    writeline(output, l);
    wait;
  end process;
end behaviour;

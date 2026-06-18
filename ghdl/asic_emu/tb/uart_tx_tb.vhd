library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;
--  Defines a testbench (without any ports)
entity uart_tx_tb is
end uart_tx_tb;
architecture behaviour of uart_tx_tb is
  component uart_tx is
    generic (
      WIDTH : integer := 64
    );
    port (
      tx_out     : out std_logic;
      tx_busy    : out std_logic;
      tx_data    : in  std_logic_vector(WIDTH-1 downto 0);
      ld_tx_data : in  std_logic;
      tx_enable  : in  std_logic;
      clk        : in  std_logic;
      reset_n    : in  std_logic
      );
  end component;
  signal count      : integer := 0;
  signal clk        : std_logic;
  signal reset_n    : std_logic := '0';
  signal tx_data    : std_logic_vector(63 downto 0) := x"3333FFFF00003333";
  signal ld_tx_data : std_logic := '0';
  signal tx_enable  : std_logic := '1';
  signal tx_out     : std_logic;
  signal tx_busy    : std_logic;
begin
  uut0: uart_tx port map (
    tx_out     => tx_out,
    tx_busy    => tx_busy,
    tx_data    => tx_data,
    ld_tx_data => ld_tx_data,
    tx_enable  => tx_enable,
    clk        => clk,
    reset_n    => reset_n
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
    ld_tx_data <= '0';
    wait for 30 ns;
    -- Pulse ld_tx_data for one clock to start transmission
    ld_tx_data <= '1';
    wait for 10 ns;
    ld_tx_data <= '0';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    wait for 10 ns;
    write (l, String'("c: "));
    write (l, count, left, 4);
    write (l, String'(" | tx_out: "));
    write (l, tx_out);
    write (l, String'(" tx_busy: "));
    write (l, tx_busy);
    if (reset_n = '0') then
      write (l, String'(" (RESET)"));
    end if;
    writeline(output, l);
  end process;

  comment_process : process
    variable l : line;
  begin
    wait until (count=4);
    write(l, String'("INFO:  tx_data = 0x3333FFFF00003333"));
    writeline(output, l);
    wait;
  end process;
end behaviour;

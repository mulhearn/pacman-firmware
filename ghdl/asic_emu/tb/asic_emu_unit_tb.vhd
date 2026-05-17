library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;
--  Defines a testbench (without any ports)
entity asic_emu_unit_tb is
end asic_emu_unit_tb;
architecture behaviour of asic_emu_unit_tb is
  component asic_emu_unit is
    port (
      UCLK_I  : in  std_logic;
      G_I     : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      H_I     : in  std_logic_vector(C_NUM_TILE-1 downto 0);
      POSI_I  : in  std_logic_vector(C_NUM_UART-1 downto 0);
      PISO_O  : out std_logic_vector(C_NUM_UART-1 downto 0)
      );
  end component;
  signal count   : integer := 0;
  signal clk     : std_logic;
  signal g       : std_logic_vector(C_NUM_TILE-1 downto 0) := (others => '0');
  signal h       : std_logic_vector(C_NUM_TILE-1 downto 0) := (others => '0');
  signal posi    : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '1');  -- idle high
  signal piso    : std_logic_vector(C_NUM_UART-1 downto 0);
  -- Test packet to send: a recognizable pattern
  constant TEST_PACKET : std_logic_vector(63 downto 0) := x"3333FFFF00003333";
begin
  uut0: asic_emu_unit port map (
    UCLK_I => clk,
    G_I    => g,
    H_I    => h,
    POSI_I => posi,
    PISO_O => piso
  );
  reset_process : process
  begin
    -- G_I bit 0 is reset_n to LArPix digital_core (active low)
    g(0) <= '0';
    wait for 20 ns;
    g(0) <= '1';
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
    posi <= (others => '1');
    wait for 40 ns;
    -- Drive a UART packet on POSI_I(0): start bit + 64 data bits LSB-first
    -- (other lines held idle high)
    posi(0) <= '0';     -- start bit
    wait for 10 ns;
    for i in 0 to 63 loop
      posi(0) <= TEST_PACKET(i);
      wait for 10 ns;
    end loop;
    posi(0) <= '1';     -- return to idle (stop bit / idle line)
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    wait for 10 ns;
    write (l, String'("c: "));
    write (l, count, left, 4);
    write (l, String'(" | posi: 0x"));
    hwrite (l, posi);
    write (l, String'(" piso: 0x"));
    hwrite (l, piso);
    if (g(0) = '0') then
      write (l, String'(" (RESET)"));
    end if;
    writeline(output, l);
  end process;

  comment_process : process
    variable l : line;
  begin
    wait until (count=5);
    write(l, String'("INFO:  Driving start bit on POSI_I(0)"));
    writeline(output, l);
    wait until (count=6);
    write(l, String'("INFO:  Sending test packet"));
    writeline(output, l);
    wait;
  end process;
end behaviour;

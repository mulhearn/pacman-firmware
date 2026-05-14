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
  signal posi    : std_logic_vector(C_NUM_UART-1 downto 0) := (others => '0');
  signal piso    : std_logic_vector(C_NUM_UART-1 downto 0);
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
    -- Hold POSI quiet during reset
    posi <= (others => '0');
    wait for 30 ns;
    -- Walk a 1 across the four UART receive lines.
    -- With the loopback stub, PISO should mirror POSI immediately.
    posi <= "0001";
    wait for 10 ns;
    posi <= "0010";
    wait for 10 ns;
    posi <= "0100";
    wait for 10 ns;
    posi <= "1000";
    wait for 10 ns;
    -- All four high simultaneously
    posi <= "1111";
    wait for 10 ns;
    -- Idle
    posi <= (others => '0');
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    wait for 10 ns;
    write (l, String'("c: "));
    write (l, count, left, 4);
    write (l, String'(" | g0: "));
    write (l, g(0));
    write (l, String'(" h0: "));
    write (l, h(0));
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
    write(l, String'("INFO:  Resetting (G_I(0) low)"));
    writeline(output, l);
    wait until (count=3);
    write(l, String'("INFO:  Releasing reset, holding POSI quiet"));
    writeline(output, l);
    wait until (count=4);
    write(l, String'("INFO:  Walking 1 across POSI"));
    writeline(output, l);
    wait until (count=8);
    write(l, String'("INFO:  All POSI lines high"));
    writeline(output, l);
    wait;
  end process;
end behaviour;

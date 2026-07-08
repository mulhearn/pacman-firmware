library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
use work.common.all;


entity timestamp_tb is
end timestamp_tb;

architecture behaviour of timestamp_tb is
  component timestamp is
    port (
      CLK_I       : in  std_logic;
      RST_I       : in  std_logic;
      ENABLE_I    : in  std_logic;
      TIMESTAMP_O     : out std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0)
    );
  end component;

  signal clk              : std_logic;
  signal rst              : std_logic;
  signal enable           : std_logic;
  signal ts               : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);

  signal show_output      : std_logic := '0';
  signal count            : integer := 0;

begin
  uut: timestamp port map (
    CLK_I        => clk,
    RST_I        => rst,
    ENABLE_I     => enable,
    TIMESTAMP_O  => ts
  );

  areset_process : process
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

  enable_process : process
  begin
    wait for 1 ns;
    enable <= '1';
    wait for 10 ns;
    enable <= '0';
    wait for 20 ns;
  end process;

  show_process : process
  begin
    show_output <= '1';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    wait for 10 ns;
    if (show_output='1') then
      write (l, String'("c: "));
      write (l, count, left, 5);
      write  (l, String'(" e: "));
      write  (l, enable);
      write  (l, String'("| timestamp: "));
      hwrite  (l, ts);
      if (rst = '1') then
        write (l, String'(" (RESET)"));
      end if;
      writeline(output, l);
    end if;
  end process;





end behaviour;

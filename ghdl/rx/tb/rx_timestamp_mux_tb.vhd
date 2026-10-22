----------------------------------------------------------------------------------------------------
-- rx_timestamp_mux_tb:  RX timestamp multiplexer test bench
--
-- Select one of the 44 RX channel timestamps (40 UARTs + 4 extra).  The output follows the select
-- one clock later (registered);  select 3F (no channel) gives zero.
--
-- Shows one line per clock: sel | ts out.
--
-- Scenario: selects 8, 9, A, then 3F
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity rx_timestamp_mux_tb is
end rx_timestamp_mux_tb;

architecture behaviour of rx_timestamp_mux_tb is
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal sel       : std_logic_vector(C_SELECT_WIDTH-1 downto 0) := (others => '0');
  signal timestamp : rx_timestamp_array_t := (others => (others => '0'));
  signal tso       : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
begin
  uut: entity work.rx_timestamp_mux port map (
    CLK_I       => clk,
    RST_I       => rst,
    SEL_I       => sel,
    TIMESTAMP_I => timestamp,
    TIMESTAMP_O => tso
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

  data_process : process
  begin
    timestamp(0)(15 downto 0)  <= x"1234";
    timestamp(1)(15 downto 0)  <= x"AAAA";
    timestamp(2)(15 downto 0)  <= x"BBBB";
    timestamp(3)(15 downto 0)  <= x"CCCC";
    timestamp(8)(15 downto 0)  <= x"8888";   -- the channels selected below
    timestamp(9)(15 downto 0)  <= x"9999";
    timestamp(10)(15 downto 0) <= x"AAA0";
    wait;
  end process;

  select_process : process
  begin
    sel <= (others => '0');
    wait for 21 ns;
    sel(3 downto 0) <= x"8";
    wait for 10 ns;
    sel(3 downto 0) <= x"9";
    wait for 10 ns;
    sel(3 downto 0) <= x"A";
    wait for 10 ns;
    sel <= (others => '1');
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 10 loop
      wait for 10 ns;
      strip(count, "sel " & hex("00" & sel) & " | ts " & hex(tso) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

----------------------------------------------------------------------------------------------------
-- tx_data_mux_tb:  TX data multiplexer test bench
--
-- Select one of the 40 UART TX data words.  The output follows the select one clock later
-- (registered);  select 3F (no UART) gives zero.
--
-- Shows one line per clock: sel | out.
--
-- Scenario: selects 1, 2, then 3F
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity tx_data_mux_tb is
end tx_data_mux_tb;

architecture behaviour of tx_data_mux_tb is
  signal count : integer := 0;
  signal clk   : std_logic;
  signal rst   : std_logic;
  signal sel   : std_logic_vector(C_SELECT_WIDTH-1 downto 0) := (others => '0');
  signal data  : uart_data_array_t := (others => (others => '0'));
  signal dout  : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
begin
  uut: entity work.tx_data_mux port map (
    CLK_I  => clk,
    RST_I  => rst,
    SEL_I  => sel,
    DATA_I => data,
    DATA_O => dout
  );

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

  data_process : process
  begin
    data(0)(15 downto 0) <= x"1234";
    data(1)(15 downto 0) <= x"AAAA";
    data(2)(15 downto 0) <= x"BBBB";
    data(3)(15 downto 0) <= x"CCCC";
    wait;
  end process;

  select_process : process
  begin
    sel <= (others => '0');
    wait for 21 ns;
    sel(3 downto 0) <= x"1";
    wait for 10 ns;
    sel(3 downto 0) <= x"2";
    wait for 10 ns;
    sel <= (others => '1');
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 10 loop
      wait for 10 ns;
      strip(count, "sel " & hex("00" & sel) & " | out " & hex(dout) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

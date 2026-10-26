----------------------------------------------------------------------------------------------------
-- rx_data_mux_tb:  RX data multiplexer test bench
--
-- Two independent selects into the 40 UART data words:  A for the buffer, B for the look feature;
-- A also looks up the word type in the LUT.  The outputs follow the selects one clock later
-- (registered);  select 3F (no UART) gives zero.
--
-- Shows one line per clock: sel a, b | data out a, b | wtype.
--
-- Scenario: LUT 44444444 (word type D);  selects 8/9, swapped, then 3F  -- (alternatives in
-- comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity rx_data_mux_tb is
end rx_data_mux_tb;

architecture behaviour of rx_data_mux_tb is
  signal count : integer := 0;
  signal clk   : std_logic;
  signal rst   : std_logic;
  signal sel_a : std_logic_vector(C_SELECT_WIDTH-1 downto 0) := (others => '0');
  signal sel_b : std_logic_vector(C_SELECT_WIDTH-1 downto 0) := (others => '0');
  signal data  : uart_data_array_t := (others => (others => '0'));
  signal out_a : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  signal out_b : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
  signal wtype : std_logic_vector(C_BYTE-1 downto 0);
  signal lut : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  -- the mux configuration (alternatives in comments):
  lut <= x"44444444";                                           -- word type D for every entry
  --lut <= x"44434241";                                         -- types A-D:  shows the entry used

  uut: entity work.rx_data_mux port map (
    CLK_I     => clk,
    RST_I     => rst,
    SEL_A_I   => sel_a,
    SEL_B_I   => sel_b,
    DATA_I    => data,
    DATA_A_O  => out_a,
    DATA_B_O  => out_b,
    LUT_I     => lut,
    WTYPE_A_O => wtype
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
    data(0)(15 downto 0) <= x"1234";
    data(1)(15 downto 0) <= x"AAAA";
    data(2)(15 downto 0) <= x"BBBB";
    data(3)(15 downto 0) <= x"CCCC";
    data(8)(15 downto 0) <= x"8888";   -- the channels selected below
    data(9)(15 downto 0) <= x"9999";
    wait;
  end process;

  select_process : process
  begin
    sel_a <= (others => '0');
    sel_b <= (others => '0');
    wait for 21 ns;
    sel_a(3 downto 0) <= x"8";
    sel_b(3 downto 0) <= x"9";
    wait for 10 ns;
    sel_a(3 downto 0) <= x"9";
    sel_b(3 downto 0) <= x"8";
    wait for 10 ns;
    sel_a <= (others => '1');
    sel_b <= (others => '1');
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 10 loop
      wait for 10 ns;
      strip(count, "sel a " & hex("00" & sel_a) & " b " & hex("00" & sel_b) & " | a " & hex(out_a) & " b " & hex(out_b)
            & " | wtype " & hex(wtype) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

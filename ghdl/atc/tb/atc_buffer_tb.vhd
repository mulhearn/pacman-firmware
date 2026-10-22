----------------------------------------------------------------------------------------------------
-- atc_buffer_tb:  ATC buffer test bench
--
-- The per-tile ATC signals:  the output follows the input after a UART strobe (plus the phase);
-- CONFIG bits 17-8 invert tiles.
--
-- Shows one line per clock: u = the UART strobe | in | out (the 10 tiles).
--
-- Scenario: tiles 0-4 inverted, phase 1, UART strobe every 3 clocks;  the input all high, then
-- 0000000111 from 80 ns  -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity atc_buffer_tb is
end atc_buffer_tb;

architecture behaviour of atc_buffer_tb is
  signal count   : integer := 0;
  signal clk     : std_logic;
  signal rst     : std_logic;
  signal uart    : std_logic;
  signal sig_in  : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal sig_out : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal config : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  -- the buffer configuration (alternatives in comments):
  config <= x"00001F01";                                        -- tiles 0-4 inverted, phase 1
  --config <= x"00000001";                                      -- no tile inverted, phase 1
  --config <= x"0003FF01";                                      -- all tiles inverted, phase 1
  --config <= x"00001F00";                                      -- tiles 0-4 inverted, phase 0

  uut: entity work.atc_buffer port map (
    CLK_I    => clk,
    RST_I    => rst,
    UART_I   => uart,
    SIG_I    => sig_in,
    CONFIG_I => config,
    SIG_O    => sig_out
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

  uart_process : process
  begin
    uart <= '1';
    wait for 10 ns;
    uart <= '0';
    wait for 20 ns;
  end process;

  input_process : process
  begin
    sig_in <= (others => '0');
    wait for 20 ns;
    sig_in <= (others => '1');
    wait for 60 ns;
    sig_in <= "0000000111";
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 20 loop
      wait for 10 ns;
      strip(count, "u " & bits(uart) & " | in " & bits(sig_in) & " | out " & bits(sig_out) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

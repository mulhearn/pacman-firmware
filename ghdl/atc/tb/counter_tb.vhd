----------------------------------------------------------------------------------------------------
-- counter_tb:  counter test bench
--
-- Counts INCREMENT rising edges while RUN is high;  the output is the count (low 16 bits) and the
-- integral (high 16 bits), cleared by CLEAR.  The count holds while RUN is low;  CLEAR zeroes count
-- and integral.
--
-- Shows one line per clock: inc, run, clear | integral, count.
--
-- Scenario: RUN high, low from 100 ns, CLEAR at 180 ns, then RUN again
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity counter_tb is
end counter_tb;

architecture behaviour of counter_tb is
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal update_in : std_logic;
  signal run       : std_logic;
  signal clear     : std_logic;
  signal cnt       : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  uut: entity work.counter port map (
    CLK_I       => clk,
    RST_I       => rst,
    INCREMENT_I => update_in,
    RUN_I       => run,
    CLEAR_I     => clear,
    COUNT_O     => cnt
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

  counter_process : process
  begin
    run   <= '1';
    clear <= '0';
    wait for 100 ns;
    note("RUN low");
    run   <= '0';
    wait for 80 ns;
    note("CLEAR (one clock), then RUN high");
    clear <= '1';
    wait for 10 ns;
    run   <= '1';
    clear <= '0';
    wait;
  end process;

  -- INCREMENT pulses:  1, 2, 2 and 1 clocks long
  update_process : process
  begin
    update_in <= '0';
    wait for 31 ns;
    update_in <= '1'; wait for 10 ns; update_in <= '0'; wait for 30 ns;
    update_in <= '1'; wait for 20 ns; update_in <= '0'; wait for 30 ns;
    update_in <= '1'; wait for 20 ns; update_in <= '0'; wait for 30 ns;
    update_in <= '1'; wait for 10 ns; update_in <= '0';
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 30 loop
      wait for 10 ns;
      strip(count, "inc " & bits(update_in) & " run " & bits(run) & " clear " & bits(clear)
            & " | integral " & hex(cnt(31 downto 16)) & " count " & hex(cnt(15 downto 0)) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

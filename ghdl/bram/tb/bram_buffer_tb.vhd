----------------------------------------------------------------------------------------------------
-- bram_buffer_tb:  capture buffer test bench
--
-- ARM starts a capture;  a rising edge of the trigger bit triggers it (or TRIG_I, when enabled),
-- TRIG_O pulses, POST more samples are written, then it is done.  Readout:  START points at the
-- oldest sample, NEXT advances, DATA one clock later.
--
-- Shows one line per clock: se | sample (hex) | a t d = armed, triggered, done | trig_o | count,
-- trigger position | data (hex).
--
-- Scenario: buffer of 8 samples of 8 bits, a sample every clock = its clock count;  trigger:
-- rising edge of bit 3, POST 2;  ARM at 30 ns;  readout from 200 ns  -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity bram_buffer_tb is
end bram_buffer_tb;

architecture behaviour of bram_buffer_tb is
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal sample    : std_logic_vector(7 downto 0);
  signal se        : std_logic;
  signal trig_bit  : std_logic_vector(4 downto 0);
  signal trig_edge : std_logic_vector(1 downto 0);
  signal post      : std_logic_vector(31 downto 0);
  signal enable, trig_en, trig_i, trig_o : std_logic;
  signal arm, frc, start, nxt : std_logic := '0';
  signal armed, triggered, done : std_logic;
  signal trig_pos, cnt, data    : std_logic_vector(31 downto 0);
begin
  -- the trigger configuration (alternatives in comments):
  trig_bit  <= "00011";                                         -- bit 3
  trig_edge <= "00";                                            -- rising
  --trig_edge <= "01";                                          -- falling
  post      <= x"00000002";                                     -- 2 after the trigger
  --post      <= x"00000000";                                   -- the triggering sample last
  enable    <= '1';                                             -- acquisition enabled
  --enable    <= '0';                                           -- disabled:  writes nothing
  trig_en   <= '0';                                             -- TRIG_I ignored
  --trig_en   <= '1';                                           -- TRIG_I (at count 6) first

  uut: entity work.bram_buffer
    generic map (
      C_DEPTH_LOG2 => 3,
      C_WIDTH      => 8
    )
    port map (
      CLK_I       => clk,
      RST_I       => rst,
      SAMPLE_I    => sample,
      SE_I        => se,
      TS_I        => (others => '0'),
      ENABLE_I    => enable,
      TRIG_BIT_I  => trig_bit,
      TRIG_EDGE_I => trig_edge,
      TRIG_EN_I   => trig_en,
      POST_I      => post,
      ARM_I       => arm,
      FORCE_I     => frc,
      START_I     => start,
      NEXT_I      => nxt,
      TRIG_I      => trig_i,
      TRIG_O      => trig_o,
      ARMED_O     => armed,
      TRIGGERED_O => triggered,
      DONE_O      => done,
      TRIG_POS_O  => trig_pos,
      COUNT_O     => cnt,
      TRIG_TS_O   => open,
      DATA_O      => data
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

  sample <= std_logic_vector(to_unsigned(count mod 256, 8));
  trig_i <= '1' when count = 6 else '0';
  se     <= '1';

  command_process : process
  begin
    wait for 31 ns;
    arm <= '1';
    wait for 10 ns;
    arm <= '0';
    wait for 160 ns;
    start <= '1';
    wait for 10 ns;
    start <= '0';
    for i in 1 to 7 loop
      wait for 10 ns;
      nxt <= '1';
      wait for 10 ns;
      nxt <= '0';
    end loop;
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 38 loop
      wait for 10 ns;
      strip(count, "se " & bits(se) & " | sample " & hex(sample) & " | a t d " & bits(armed) & " " &
                   bits(triggered) & " " & bits(done) & " | " & bits(trig_o) & " | count " &
                   dec(to_integer(unsigned(cnt)), 2) & " pos " & dec(to_integer(unsigned(trig_pos)), 2) &
                   " | data " & hex(data(7 downto 0)) &
                   mark(start, "(START)") & mark(nxt, "(NEXT)") & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

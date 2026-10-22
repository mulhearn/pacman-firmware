----------------------------------------------------------------------------------------------------
-- atc_counter_tb:  ATC counters test bench
--
-- The ATC counters, driven by commands (UPDATE + COMMAND, atc_counter.vhd):  0 no op, 1 clear, 2
-- start, 3 stop, 4/5/6/7 read M/G/H/I channel C.
--
-- Shows one line per clock: lemo a | g (10 tiles) | the command, named | integral (high 16), count
-- (low 16).
--
-- Scenario: read G 1 (the tile-1 G input, pulsing), stop, clear, start, read again
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity atc_counter_tb is
end atc_counter_tb;

architecture behaviour of atc_counter_tb is
  signal count   : integer := 0;
  signal clk     : std_logic;
  signal rst     : std_logic;
  signal incr_la : std_logic := '0';
  signal incr_g  : std_logic_vector(C_NUM_TILE-1 downto 0) := (others => '0');
  signal update  : std_logic;
  signal command : std_logic_vector(7 downto 0);
  signal count_o : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  function cmd(u : std_logic; c : std_logic_vector(7 downto 0)) return string is
    type names_t is array (0 to 7) of string(1 to 6);
    constant NAME : names_t := ("no op ", "CLEAR ", "START ", "STOP  ", "READ M", "READ G", "READ H", "READ I");
  begin
    if u /= '1' then return "          "; end if;
    if c(7) = '1' then return "reserved  "; end if;
    return NAME(to_integer(unsigned(c(6 downto 4)))) & " " & hex(c(3 downto 0)) & " ";
  end function;
begin
  uut: entity work.atc_counter port map (
    CLK_I     => clk,
    RST_I     => rst,
    LEMO_A_I  => incr_la,
    LEMO_B_I  => '0',
    POKE_A_I  => '0',
    POKE_B_I  => '0',
    POKE_C_I  => '0',
    POKE_D_I  => '0',
    M_I       => (others => '0'),
    G_I       => incr_g,
    H_I       => (others => '0'),
    UPDATE_I  => update,
    COMMAND_I => command,
    COUNT_O   => count_o
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
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process;

  command_process : process
    procedure send(u : std_logic; c : std_logic_vector(7 downto 0); t : time) is
    begin update <= u; command <= c; wait for t; end procedure;
  begin
    send('0', x"00", 51 ns);
    send('1', x"51", 60 ns);   -- read G 1
    send('1', x"30", 10 ns);   -- stop
    send('1', x"10", 10 ns);   -- clear
    send('1', x"51", 10 ns);
    send('0', x"00", 10 ns);
    send('1', x"20", 10 ns);   -- start
    send('1', x"51", 10 ns);
    send('0', x"00", 50 ns);
    send('1', x"51", 10 ns);
    send('1', x"70", 10 ns);   -- read I 0
    send('0', x"00", 10 ns);
    wait;
  end process;

  -- LEMO A:  pulses every 70 ns;  G(1):  pulses every 30 ns
  incr_la_process : process
  begin
    wait for 1 ns;
    incr_la <= '0'; wait for 30 ns;
    incr_la <= '1'; wait for 10 ns;
    incr_la <= '0'; wait for 30 ns;
    incr_la <= '1';
  end process;

  incr_g_process : process
  begin
    wait for 1 ns;
    incr_g(1) <= '0'; wait for 20 ns;
    incr_g(1) <= '1'; wait for 10 ns;
    incr_g(1) <= '0'; wait for 20 ns;
    incr_g(1) <= '1'; wait for 10 ns;
    incr_g(1) <= '0';
  end process;

  output_process : process
  begin
    fold(true);
    while count < 30 loop
      wait for 10 ns;
      strip(count, "lemo a " & bits(incr_la) & " | g " & bits(incr_g) & " | " & cmd(update, command)
        & "| integral " & hex(count_o(31 downto 16)) & " count " & hex(count_o(15 downto 0)) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

----------------------------------------------------------------------------------------------------
-- global_status_tb:  global status test bench
--
-- The LEDs follow the LED config;  the status output is a constant (CAFE).
--
-- Shows one line per clock: config | status | leds.
--
-- Scenario: first LED on at clock 5, both at clock 10
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity global_status_tb is
end global_status_tb;

architecture behaviour of global_status_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal config : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal status : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal leds   : std_logic_vector(C_NUM_LED-1 downto 0) := (others => '0');
begin
  uut: entity work.global_status port map (
    CLK_I           => clk,
    RST_I           => rst,
    LED_CONFIG_I    => config,
    GLOBAL_STATUS_O => status,
    LED_O           => leds
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

  config_process : process
  begin
    config <= (others => '0');
    wait until (count=5);
    note("LED config:  first LED on");
    config(0) <= '1';
    wait until (count=10);
    note("LED config:  both LEDs on");
    config(1) <= '1';
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 15 loop
      wait for 10 ns;
      strip(count, "config " & hex(config) & " | status " & hex(status) & " | leds " & bits(leds) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

-- Diagram testbench (make waveforms):  global_unit on the register bus, for the firmware description
-- (global.pdf):  write ENABLES (power and all tiles) and LEDS (both on), then read ENABLES and STATUS back.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;

entity global_diagram_tb is
end global_diagram_tb;

architecture behaviour of global_diagram_tb is
  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';
  signal raddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal rdata   : std_logic_vector(31 downto 0);
  signal rupdate : std_logic := '0';
  signal rack    : std_logic;
  signal waddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wupdate : std_logic := '0';
  signal wack    : std_logic;
  signal power   : std_logic;
  signal tiles   : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal leds    : std_logic_vector(C_NUM_LED-1 downto 0);
begin
  uut: entity work.global_unit port map (
    ACLK                => clk,
    RST_I               => rst,
    S_REGBUS_RB_RADDR   => raddr,
    S_REGBUS_RB_RDATA   => rdata,
    S_REGBUS_RB_RUPDATE => rupdate,
    S_REGBUS_RB_RACK    => rack,
    S_REGBUS_RB_WUPDATE => wupdate,
    S_REGBUS_RB_WADDR   => waddr,
    S_REGBUS_RB_WDATA   => wdata,
    S_REGBUS_RB_WACK    => wack,
    ANALOG_PWR_EN_O     => power,
    TILE_EN_O           => tiles,
    LED_O               => leds
  );

  clk <= not clk after 5 ns;
  rst <= '0' after 20 ns;

  process
    function a(reg : integer) return std_logic_vector is
    begin return std_logic_vector(to_unsigned(C_SCOPE_GLOBAL * 16#1000# + reg, 16)); end function;
    procedure wr(reg : integer; d : std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
      waddr <= a(reg);  wdata <= d;  wupdate <= '1';
      wait until rising_edge(clk);
      wait for 1 ns;
      waddr <= (others => '0');  wdata <= (others => '0');  wupdate <= '0';
    end procedure;
    procedure rd(reg : integer) is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
      raddr <= a(reg);  rupdate <= '1';
      wait until rising_edge(clk);
      wait for 1 ns;
      raddr <= (others => '0');  rupdate <= '0';
    end procedure;
  begin
    wait for 40 ns;
    wr(C_ADDR_GLOBAL_ENABLES, x"000103FF");
    wr(C_ADDR_GLOBAL_LEDS,    x"00000003");
    wait for 20 ns;
    rd(C_ADDR_GLOBAL_ENABLES);
    rd(C_ADDR_GLOBAL_STATUS);
    wait;
  end process;
end behaviour;

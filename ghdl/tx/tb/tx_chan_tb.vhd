library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;

entity tx_chan_tb is
end tx_chan_tb;

architecture behaviour of tx_chan_tb is
  component tx_chan is
    port (
      CLK_I       : in  std_logic;
      RST_I       : in  std_logic;
      BAUD_I      : in  std_logic;
      CONFIG_I    : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      STATUS_O    : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DATA_I      : in  std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
      VALID_I     : in  std_logic;
      READY_O     : out std_logic;
      TX_O        : out std_logic;
      DEBUG_O     : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
      );
  end component;

  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal status    : std_logic_vector(31  downto 0);
  signal status_z  : std_logic_vector(31  downto 0);
  signal valid     : std_logic := '0';
  signal ready     : std_logic;
  signal tx        : std_logic;
  signal baud      : std_logic;
  signal data      : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
begin
  uut: tx_chan port map (
      CLK_I    => clk,
      RST_I    => rst,
      BAUD_I   => baud,
      CONFIG_I => x"00000002",
      DEBUG_O  => status,
      STATUS_O => status_z,
      DATA_I   => data,
      VALID_I  => valid,
      READY_O  => ready,
      TX_O     => tx
  );

  rst_process : process
  begin
    rst <= '1';
    wait for 10 ns;
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

  baud_process : process
  begin
    baud <= '1';
    wait for 10 ns;
    baud <= '0';
    wait for 20 ns;
  end process;

  tx_process : process
    variable l : line;
  begin
    data  <= (others => '0');
    valid <= '0';
    wait for 1 ns;
    wait for 20 ns;
    data  <= x"00FF00FF00FF00FF";
    valid <= '1';
    wait until ((rising_edge(clk)) and (ready='1'));
    wait for 1 ns;
    data  <= (others => '0');
    valid <= '0';
    wait for 40 ns;
    valid <= '1';
    data  <= x"AAAAAAAAAAAAAAAA";
    wait until ((rising_edge(clk)) and (ready='1'));
    wait for 1 ns;
    data  <= (others => '0');
    valid <= '0';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin

    wait for 10 ns;

    case status_z(5 downto 4) is
      when "00"  => write(l, String'("IDLE:  "));
      when "01"  => write(l, String'("SHIFT: "));
      when "10"  => write(l, String'("STOP:  "));
      when "11"  => write(l, String'("DELAY: "));
      when others => write(l, String'("XXXXX: "));
    end case;

    write (l, String'("c: "));
    write (l, count, left, 4);
    write  (l, String'("b: "));
    write  (l, baud);
    write  (l, String'("| vr: "));
    write  (l, valid);
    write  (l, ready);
    write  (l, String'(" | tx: "));
    write  (l, tx);

    if (status(3) = '1') then
      write (l, String'(" (START) "));
    end if;

    if ((valid = '1') and (ready = '1')) then
      write (l, String'(" (BEAT) "));
    end if;


    if (rst = '1') then
      write (l, String'(" (RESET)"));
    end if;
    writeline(output, l);
  end process;



end behaviour;

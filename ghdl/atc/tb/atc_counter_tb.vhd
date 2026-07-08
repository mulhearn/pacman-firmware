library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;

--  Defines a testbench (without any ports)
entity atc_counter_tb is
end atc_counter_tb;

architecture behaviour of atc_counter_tb is
  component atc_counter is
    port (
      CLK_I	               : in  std_logic;
      RST_I	               : in  std_logic;

     --input signal
      LEMO_A_I	            : in  std_logic;
      LEMO_B_I	            : in  std_logic;
      POKE_A_I	            : in  std_logic;
      POKE_B_I	            : in  std_logic;
      POKE_C_I	            : in  std_logic;
      POKE_D_I	            : in  std_logic;
      M_I                   : in std_logic_vector(C_NUM_MARKER -1 downto 0) ;
      G_I                   : in std_logic_vector(C_NUM_TILE -1  downto 0) ;
      H_I                   : in std_logic_vector(C_NUM_TILE -1 downto 0) ;

      UPDATE_I              : in  std_logic;
      COMMAND_I             : in  std_logic_vector(7 downto 0);

    --output
      COUNT_O               : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)


  );
  end component;

  signal clk            : std_logic;
  signal rst            : std_logic;

  signal incr_la        : std_logic := '0';
  signal incr_lb        : std_logic := '0';
  signal incr_pa        : std_logic := '0';
  signal incr_pb        : std_logic := '0';
  signal incr_pc        : std_logic := '0';
  signal incr_pd        : std_logic := '0';
  signal incr_m         : std_logic := '0';
  signal incr_g         : std_logic_vector(C_NUM_TILE-1 downto 0) := (others => '0');
  signal incr_h         : std_logic_vector(C_NUM_TILE-1 downto 0) :=  (others => '0');
  signal update         : std_logic;
  signal command        : std_logic_vector(7 downto 0);
  signal count_o        : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal poke_in        : std_logic;
  signal count          : integer := 0;
  signal show_output    : std_logic := '0';

begin
  uut: atc_counter port map (
    CLK_I	     => clk,
    RST_I 	     => rst,
    LEMO_A_I	     => incr_la,
    LEMO_B_I	     => incr_lb,
    POKE_A_I	     => incr_pa,
    POKE_B_I	     => incr_pb,
    POKE_C_I	     => incr_pc,
    POKE_D_I	     => incr_pd,
    M_I              => (others => '0'),
    G_I              => incr_g,
    H_I              => incr_h,
    UPDATE_I         => update,
    COMMAND_I        => command,
    COUNT_O          => count_o
  );

  areset_process : process
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

  proc_command : process
  begin
    wait for 1 ns;
    update <= '0';
    command <= "00000000";
    wait for 50 ns    ;
    update <= '1';
    command <= "01010001";
    wait for 60 ns    ;
    update <= '1';
    command <= "00110000";
    wait for 10 ns;
    update <= '1';
    command <= "00010000";
    wait for 10 ns;
    update <= '1';
    command <= "01010001";
    wait for 10 ns;
    update <= '0';
    command <= "00000000";
    wait for 10 ns;
    update <= '1';
    command <= "00100000";
    wait for 10 ns;
    update <= '1';
    command <= "01010001";
    wait for 10 ns;
    update <= '0';
    command <= "00000000";
    wait for 50 ns;
    update <= '1';
    command <= "01010001";
    wait for 10 ns;
    update <= '1';
    command <= "01110000";
    wait for 10 ns;
    update <= '0';
    command <= "00000000";
    wait;
  end process;

  incr_in_a : process
  begin
    wait for 1 ns;
    incr_la <= '0';
    wait for 30 ns;
    incr_la <= '1';
    wait for 10 ns;
    incr_la <= '0';
    wait for 30 ns;
    incr_la <= '1';
  end process;



  incr_in_g : process
  begin
    incr_g <= (others => '0');
    wait for 1 ns;
    incr_g(1) <= '0';
    wait for 20 ns;
    incr_g(1) <= '1';
    wait for 10 ns;
    incr_g(1) <= '0';
    wait for 20 ns;
    incr_g(1) <= '1';
    wait for 10 ns;
    incr_g(1) <= '0';
  end process;
  show_process : process
  begin
    show_output <= '1';
    wait until (count = 200);
    wait for 10 ns;
    show_output <= '0';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    wait for 10 ns;

    if (show_output='1') then
      write (l, String'("c: "));
      write (l, count, left, 5);
      write  (l, String'(" clk: "));
      write  (l, clk);

      write  (l, String'("| la: "));
      write  (l, incr_la);
      write  (l, String'(" b: "));
      write  (l, incr_lb);
      write  (l, String'("| pa: "));
      write  (l, incr_pa);
      write  (l, String'(" b: "));
      write  (l, incr_pb);
      write  (l, String'(" c: "));
      write  (l, incr_pc);
      write  (l, String'(" d: "));
      write  (l, incr_pd);
      write  (l, String'("| g: "));
      write  (l, incr_g);
      write  (l, String'(" h: "));
      write  (l, incr_h);
      write  (l, String'("| up: "));
      write  (l, update);
      write  (l, String'(" cmd: "));
      write  (l, command);
     -- write  (l, String'(" count_stop: "));
     -- write  (l, not start);

      --write  (l, String'(" count_reset: "));
      --write  (l, count_reset);

      write  (l, String'("| counter: 0x"));
      hwrite  (l, COUNT_O);


      if (rst = '1') then
        write (l, String'(" (RESET)"));
      end if;
      writeline(output, l);
    end if;
  end process;





end behaviour;

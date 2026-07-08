library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;

--  Defines a testbench (without any ports)
entity atc_registers_tb is
end atc_registers_tb;

architecture behaviour of atc_registers_tb is
  component atc_registers is
    port (
      CLK_I : in std_logic;
      RST_I : in std_logic;

      S_REGBUS_RB_RUPDATE : in  std_logic;
      S_REGBUS_RB_RADDR	  : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_RDATA	  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_RACK    : out std_logic;
      S_REGBUS_RB_WUPDATE : in  std_logic;
      S_REGBUS_RB_WADDR	  : in  std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0);
      S_REGBUS_RB_WDATA	  : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      S_REGBUS_RB_WACK    : out std_logic;
      COUNT_REQ_O   : out std_logic;
      COUNT_CMD_O   : out std_logic_vector(C_BYTE_WIDTH-1 downto 0);
      COUNT_I       : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      POKE_A_O      : out std_logic;
      MASK_A_O      : out std_logic_vector(C_NUM_TILE-1 downto 0);
      POKE_B_O      : out std_logic;
      MASK_B_O      : out std_logic_vector(C_NUM_TILE-1 downto 0);
      POKE_C_O      : out std_logic;
      MASK_C_O      : out std_logic_vector(C_NUM_TILE-1 downto 0);
      POKE_D_O      : out std_logic;
      MASK_D_O      : out std_logic_vector(C_NUM_TILE-1 downto 0);
      CONFIG_INPUT_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CONFIG_UART_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CONFIG_BAUD_O   : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CONFIG_G_O      : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      CONFIG_H_O      : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LEMO_A_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LEMO_B_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_A_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_B_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_C_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_POKE_D_O  : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LOGIC_A_O : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      DST_LOGIC_B_O : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      STATUS_I      : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
      TIMESTAMP_I   : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0)
    );
  end component;

  signal count    : integer := 0;
  signal clk      : std_logic;
  signal rst      : std_logic;
  -- read signals:
  signal raddr    : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal rupdate  : std_logic := '0';
  signal rdata    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal rack     : std_logic := '0';
  -- write signals:
  signal waddr    : std_logic_vector(C_RB_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal wupdate  : std_logic := '0';
  signal wdata    : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := (others => '0');
  signal wack     : std_logic := '0';

  signal show_output : std_logic := '0';

  signal cnt_req  : std_logic;
  signal cnt_cmd  : std_logic_vector(C_BYTE_WIDTH-1 downto 0);
  signal poke_a   : std_logic;
  signal mask_a   : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal poke_b   : std_logic;
  signal mask_b   : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal poke_c   : std_logic;
  signal mask_c   : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal poke_d   : std_logic;
  signal mask_d   : std_logic_vector(C_NUM_TILE-1 downto 0);

begin
  uut0: atc_registers port map (
    CLK_I               => clk,
    RST_I               => rst,
    S_REGBUS_RB_RUPDATE => rupdate,
    S_REGBUS_RB_RADDR   => raddr,
    S_REGBUS_RB_RDATA   => rdata,
    S_REGBUS_RB_RACK    => rack,
    S_REGBUS_RB_WUPDATE => wupdate,
    S_REGBUS_RB_WADDR   => waddr,
    S_REGBUS_RB_WDATA   => wdata,
    S_REGBUS_RB_WACK    => wack,
    COUNT_REQ_O         => cnt_req,
    COUNT_CMD_O         => cnt_cmd,
    POKE_A_O            => poke_a,
    MASK_A_O            => mask_a,
    POKE_B_O            => poke_b,
    MASK_B_O            => mask_b,
    POKE_C_O            => poke_c,
    MASK_C_O            => mask_c,
    POKE_D_O            => poke_d,
    MASK_D_O            => mask_d,
    STATUS_I            => x"1234ABCD",
    COUNT_I             => x"00000002",
    TIMESTAMP_I         => x"AAAABBBBCCCCDDDD"
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

  read_process : process
  begin
    raddr   <= x"0000";
    rupdate <= '0';
    wait for 1 ns;
    wait for 20 ns;
    raddr   <= x"E000";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"E004";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"E100";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"E100";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"E104";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"E108";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"E10C";
    rupdate <= '1';
    wait for 10 ns;
    raddr   <= x"E204";
    rupdate <= '1';
    wait;
  end process;

  write_process : process
  begin
    waddr   <= x"0000";
    wdata   <= x"00000000";
    wupdate <= '0';
    wait for 1 ns;
    wait for 20 ns;
    waddr   <= x"E100";
    wdata   <= x"AAAAAAAA";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"E104";
    wdata   <= x"BBBBBBBB";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"E108";
    wdata   <= x"CCCCCCCC";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"E10C";
    wdata   <= x"DDDDDDDD";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"0000";
    wdata   <= x"00000000";
    wupdate <= '0';
    wait for 40 ns;
    waddr   <= x"E200";
    wdata   <= x"000000AB";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"E0A0";
    wdata   <= x"000003FF";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"E0B0";
    wdata   <= x"00000001";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"E0C0";
    wdata   <= x"000003FF";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"E0D0";
    wdata   <= x"00000001";
    wupdate <= '1';
    wait for 10 ns;
    waddr   <= x"0000";
    wdata   <= x"00000000";
    wupdate <= '0';
    wait;
  end process;

  show_output_process : process
  begin
    show_output<='1';
    wait until (count=20);
    wait for 10 ns;
    show_output<='0';
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    --wait for 1 ns;
    wait for 10 ns;
    if (show_output='1') then
      write (l, String'("c: "));
      write (l, count, left, 4);
      write (l, String'(" || ra: 0x"));
      hwrite (l, raddr);
      write (l, String'(" ru:"));
      write (l, rupdate);
      write (l, String'(" rd: 0x"));
      hwrite (l, rdata);
      write (l, String'(" rk:"));
      write (l, rack);
      write (l, String'(" || wa: 0x"));
      hwrite (l, waddr);
      write (l, String'(" wu:"));
      write (l, wupdate);
      write (l, String'(" wd: 0x"));
      hwrite (l, wdata);
      write (l, String'(" wk:"));
      write (l, wack);
      write (l, String'(" || cmd: "));
      write (l, cnt_req);
      write (l, String'(" 0x"));
      hwrite(l, cnt_cmd);
      write (l, String'(" || pokes: "));
      write (l, poke_a);
      write (l, poke_b);
      write (l, poke_c);
      write (l, poke_d);

      write (l, String'(" 0x"));
      hwrite(l, "00" & mask_a);
      write (l, String'(" 0x"));
      hwrite(l, "00" & mask_b);

      if (rst = '1') then
        write (l, String'(" (RESET)"));
      end if;
      writeline(output, l);
    end if;
  end process;


  comment_process : process
    variable l : line;
  begin
    write(l, String'("INFO:  Resetting:"));
    writeline(output, l);
    wait until (count=3);
    write(l, String'("INFO:  Reading status and timestamp, writing then reading a few configs:"));
    writeline(output, l);
    wait until (count=11);
    write(l, String'("INFO:  Sending count requests and pokes: (count is fixed value in testbench)"));
    writeline(output, l);
    wait;
  end process;



end behaviour;

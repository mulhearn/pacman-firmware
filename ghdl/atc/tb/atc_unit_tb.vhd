----------------------------------------------------------------------------------------------------
-- atc_unit_tb: the whole ATC unit, configured over the regbus.
--
-- Default scenario: LEMO A, toggling every 50 ns, drives G on all tiles.  A POKE C then drives H
-- on all tiles (configured inverted, so a low pulse) and marker 0, which restarts the timestamp.
-- The H counter of tile 0 is read back six times.
--
-- (Alternative scenarios are in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_utils.all;

entity atc_unit_tb is
end atc_unit_tb;

architecture behaviour of atc_unit_tb is
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal uclk      : std_logic;
  signal baud      : std_logic;
  signal rb        : rb_t := RB_IDLE;
  signal rbr       : rbr_t;
  signal lemo_a    : std_logic := '0';
  signal lemo_b    : std_logic := '0';
  signal timestamp : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal atc_h     : std_logic_vector(9 downto 0) := (others => '0');
  signal atc_g     : std_logic_vector(9 downto 0) := (others => '0');
  signal atc_m     : std_logic_vector(3 downto 0) := (others => '0');
begin
  uut0: entity work.atc_unit port map (
    ACLK                => clk,
    RST_I               => rst,
    BAUD_O              => baud,
    UCLK_O              => uclk,
    S_REGBUS_RB_RUPDATE => rb.rupdate,
    S_REGBUS_RB_RADDR   => rb.raddr,
    S_REGBUS_RB_RDATA   => rbr.rdata,
    S_REGBUS_RB_RACK    => rbr.rack,
    S_REGBUS_RB_WUPDATE => rb.wupdate,
    S_REGBUS_RB_WADDR   => rb.waddr,
    S_REGBUS_RB_WDATA   => rb.wdata,
    S_REGBUS_RB_WACK    => rbr.wack,
    LEMO_A_I            => lemo_a,
    LEMO_B_I            => lemo_b,
    TIMESTAMP_O         => timestamp,
    G_O                 => atc_g,
    H_O                 => atc_h,
    RX_MARKER_O         => atc_m,
    STATUS_O            => open
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

  lemo_process : process
  begin
    lemo_a <= '0'; lemo_b <= '0'; wait for 50 ns;
    lemo_a <= '1'; lemo_b <= '1'; wait for 50 ns;
    lemo_a <= '0'; lemo_b <= '0'; wait for 50 ns;
  end process;

  regbus_process : process
    function atc(reg : integer) return std_logic_vector is
    begin return std_logic_vector(to_unsigned(C_SCOPE_ATC * 4096 + reg, 16)); end function;
    procedure wr(reg : integer; d : std_logic_vector; txt : string) is
    begin reg_write(clk, rb, rbr, atc(reg), d, txt); end procedure;
    procedure rd(reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, atc(reg), txt); end procedure;
  begin
    wait until rst = '0';
    wr(C_ADDR_ATC_CONFIG_H,   x"0003FF00", "H output config");
    wr(C_ADDR_ATC_DST_LEMO_A, x"0004FFC1", "LEMO A destination");
    wr(C_ADDR_ATC_DST_POKE_C, x"001EFFC6", "POKE C destination");

    -- alternative settings:
    --wr(C_ADDR_ATC_CONFIG_H,     x"00000000", "H output config:  no tile inverted");
    --wr(C_ADDR_ATC_CONFIG_G,     x"00000005", "G output config:  phase 5");
    --wr(C_ADDR_ATC_DST_LEMO_A,   x"00040041", "LEMO A destination:  G of tile 0 only");
    --wr(C_ADDR_ATC_DST_LEMO_A,   x"00000000", "LEMO A destination:  none");
    --wr(C_ADDR_ATC_DST_LEMO_B,   x"00010010", "LEMO B destination:  marker 2");
    --wr(C_ADDR_ATC_CONFIG_UART,  x"00000014", "UART (ASIC clock) period 20 clock cycles");
    --wr(C_ADDR_ATC_DST_POKE_A,   x"000A0081", "POKE A destination:  G of tile 1, 10 clock cycles (LEMO A off to see it)");
    wait for 180 ns;
    wr(C_ADDR_ATC_POKE_C, x"000003FF", "POKE C, all tiles");
    --wr(C_ADDR_ATC_POKE_A, x"000003FF", "POKE A (with its destination above)");
    --wr(C_ADDR_ATC_COUNT_REQ, x"00000030", "count request:  STOP all counters");
    for i in 1 to 6 loop
      wr(C_ADDR_ATC_COUNT_REQ, x"00000060", "count request:  READ H 0 (a snapshot)");
      --wr(C_ADDR_ATC_COUNT_REQ, x"00000070", "count request:  READ I 0 (LEMO A)");
      rd(C_ADDR_ATC_COUNT, "count:  integral | count");
    end loop;
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 200 loop
      wait for 10 ns;
      strip(count, "uclk " & bits(uclk) & " baud " & bits(baud) & " lemo a " & bits(lemo_a)
            & " | G " & bits(atc_g) & " H " & bits(atc_h) & " M " & bits(atc_m)
            & " | ts " & hex(timestamp(15 downto 0)) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

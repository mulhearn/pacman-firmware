----------------------------------------------------------------------------------------------------
-- la_registers_tb:  logic analyzer register file test bench
--
-- Shows one line per register access (W writes, R reads) and lines showing how the configuration
-- outputs and command strobes are driven.
--
-- Scenario: STATUS in as 00000004 (done), TRIG_POS 0000002A, COUNT 00008000, the trigger timestamp
-- 1111111122222222, DATA 0000ABCD;  buffer depth 32768.
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_utils.all;

entity la_registers_tb is
end la_registers_tb;

architecture behaviour of la_registers_tb is
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal rb        : rb_t := RB_IDLE;
  signal rbr       : rbr_t;

  subtype word_t is std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal tile      : std_logic_vector(4*4-1 downto 0);
  signal mux_select : std_logic_vector(8*5-1 downto 0);
  signal period, phase, mode, trig, post : word_t;
  signal arm, frc, start, nxt : std_logic;

  function la(reg : integer) return std_logic_vector is
  begin return std_logic_vector(to_unsigned(C_SCOPE_LA * 4096 + reg, 16)); end function;
begin
  uut0: entity work.la_registers port map (
    CLK_I               => clk,
    RST_I               => rst,
    S_REGBUS_RB_RUPDATE => rb.rupdate,
    S_REGBUS_RB_RADDR   => rb.raddr,
    S_REGBUS_RB_RDATA   => rbr.rdata,
    S_REGBUS_RB_RACK    => rbr.rack,
    S_REGBUS_RB_WUPDATE => rb.wupdate,
    S_REGBUS_RB_WADDR   => rb.waddr,
    S_REGBUS_RB_WDATA   => rb.wdata,
    S_REGBUS_RB_WACK    => rbr.wack,
    TILE_O              => tile,
    MUX_SELECT_O        => mux_select,
    PERIOD_O            => period,
    PHASE_O             => phase,
    MODE_O              => mode,
    TRIG_O              => trig,
    POST_O              => post,
    ARM_O               => arm,
    FORCE_O             => frc,
    START_O             => start,
    NEXT_O              => nxt,
    STATUS_I            => x"00000004",
    TRIG_POS_I          => x"0000002A",
    COUNT_I             => x"00008000",
    TS_I                => x"1111111122222222",
    DATA_I              => x"0000ABCD"
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

  -- the command strobes, one line each
  strobe_process : process
  begin
    wait until rising_edge(clk);
    if (arm or frc or start or nxt) = '1' then
      print("  strobe" & mark(arm, "(ARM)") & mark(frc, "(FORCE)") & mark(start, "(START)") & mark(nxt, "(NEXT)"));
    end if;
  end process;

  regbus_process : process
    procedure wr(reg : integer; d : std_logic_vector; txt : string) is
    begin reg_write(clk, rb, rbr, la(reg), d, txt); wait for 2 ns; end procedure;  -- strobes first
    procedure rd(reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, la(reg), txt); end procedure;
  begin
    wait until rst = '0';
    note("configuration:  after reset");
    rd(C_ADDR_LA_PERIOD,   "PERIOD (1)");
    rd(C_ADDR_LA_TILE_A,   "TILE_A");
    rd(C_ADDR_LA_MUX_SELECT_A, "MUX_SELECT_A");
    note("configuration:  written all ones, read back (unused bits 0)");
    wr(C_ADDR_LA_TILE_B,   x"FFFFFFFF", "TILE_B");
    rd(C_ADDR_LA_TILE_B,   "TILE_B:  bits 3-0");
    wr(C_ADDR_LA_MUX_SELECT_H, x"FFFFFFFF", "MUX_SELECT_H");
    rd(C_ADDR_LA_MUX_SELECT_H, "MUX_SELECT_H:  bits 4-0");
    wr(C_ADDR_LA_MODE,     x"FFFFFFFF", "MODE");
    rd(C_ADDR_LA_MODE,     "MODE:  bits 1-0");
    wr(C_ADDR_LA_TRIG,     x"FFFFFFFF", "TRIG");
    rd(C_ADDR_LA_TRIG,     "TRIG:  bits 10-8, 4-0");
    wr(C_ADDR_LA_PERIOD,   x"0000000A", "PERIOD");
    wr(C_ADDR_LA_POST,     x"00000100", "POST");
    print("  tile " & hex(tile) & "  mux select " & hex(x"00" & mux_select) & "  period " & hex(period) & "  mode " &
          hex(mode) & "  trig " & hex(trig) & "  post " & hex(post));
    note("commands:  one-clock strobes;  write only");
    wr(C_ADDR_LA_ARM,      x"00000000", "ARM");
    wr(C_ADDR_LA_FORCE,    x"00000000", "FORCE");
    wr(C_ADDR_LA_START,    x"00000000", "START");
    wr(C_ADDR_LA_NEXT,     x"00000000", "NEXT");
    rd(C_ADDR_LA_ARM,      "ARM read:  no ack");
    note("status and readout:  read only");
    rd(C_ADDR_LA_STATUS,   "STATUS");
    rd(C_ADDR_LA_TRIG_POS, "TRIG_POS");
    rd(C_ADDR_LA_COUNT,    "COUNT");
    rd(C_ADDR_LA_DEPTH,    "DEPTH");
    rd(C_ADDR_LA_TS_LOWER, "TS_LOWER");
    rd(C_ADDR_LA_TS_UPPER, "TS_UPPER");
    rd(C_ADDR_LA_DATA,     "DATA");
    wr(C_ADDR_LA_STATUS,   x"00000000", "STATUS write:  no ack");
    wait;
  end process;
end behaviour;

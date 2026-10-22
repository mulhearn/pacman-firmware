----------------------------------------------------------------------------------------------------
-- atc_registers_tb:  ATC register file test bench
--
-- Shows one line per register access (W writes, R reads) and output lines
-- showing how the modules output registers are driven.
--
-- Scenario: STATUS in input as 0000ABCD, the 64-bit timestamp as 1111111122222222, and COUNT as
-- C0C0C0 and the last count command, as if the counters answered it.
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;
use work.tb_utils.all;

entity atc_registers_tb is
end atc_registers_tb;

architecture behaviour of atc_registers_tb is
  signal count     : integer := 0;
  signal clk       : std_logic;
  signal rst       : std_logic;
  signal rb        : rb_t := RB_IDLE;
  signal rbr       : rbr_t;

  signal count_req : std_logic;
  signal count_cmd : std_logic_vector(C_BYTE_WIDTH-1 downto 0);
  signal count_in  : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0) := x"C0C0C000";
  type poke_t is array (0 to 3) of std_logic;
  type mask_t is array (0 to 3) of std_logic_vector(C_NUM_TILE-1 downto 0);
  signal poke      : poke_t;
  signal mask      : mask_t;
  subtype word_t is std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal cfg_input, cfg_uart, cfg_baud, cfg_g, cfg_h : word_t;
  signal lemo_a, lemo_b, logic_a, logic_b            : word_t;
  signal dpoke_a, dpoke_b, dpoke_c, dpoke_d          : word_t;

  function atc(reg : integer) return std_logic_vector is
  begin return std_logic_vector(to_unsigned(C_SCOPE_ATC * 4096 + reg, 16)); end function;
begin
  uut0: entity work.atc_registers port map (
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
    COUNT_REQ_O         => count_req,
    COUNT_CMD_O         => count_cmd,
    COUNT_I             => count_in,
    POKE_A_O            => poke(0),
    MASK_A_O            => mask(0),
    POKE_B_O            => poke(1),
    MASK_B_O            => mask(1),
    POKE_C_O            => poke(2),
    MASK_C_O            => mask(2),
    POKE_D_O            => poke(3),
    MASK_D_O            => mask(3),
    CONFIG_INPUT_O      => cfg_input,
    CONFIG_UART_O       => cfg_uart,
    CONFIG_BAUD_O       => cfg_baud,
    CONFIG_G_O          => cfg_g,
    CONFIG_H_O          => cfg_h,
    DST_LEMO_A_O        => lemo_a,
    DST_LEMO_B_O        => lemo_b,
    DST_POKE_A_O        => dpoke_a,
    DST_POKE_B_O        => dpoke_b,
    DST_POKE_C_O        => dpoke_c,
    DST_POKE_D_O        => dpoke_d,
    DST_LOGIC_A_O       => logic_a,
    DST_LOGIC_B_O       => logic_b,
    STATUS_I            => x"0000ABCD",
    TIMESTAMP_I         => x"1111111122222222"
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

  -- the counters' answer:  the last command
  count_answer : process(clk)
  begin
    if rising_edge(clk) and count_req = '1' then count_in <= x"C0C0C0" & count_cmd; end if;
  end process;

  regbus_process : process
    procedure wr(reg : integer; d : std_logic_vector; txt : string) is
    begin reg_write(clk, rb, rbr, atc(reg), d, txt); wait for 2 ns; end procedure;  -- strobes first
    procedure rd(reg : integer; txt : string) is
    begin reg_read(clk, rb, rbr, atc(reg), txt); end procedure;
  begin
    wait until rst = '0';
    note("configs and destinations:  after reset");
    rd(C_ADDR_ATC_CONFIG_UART,  "config UART");
    rd(C_ADDR_ATC_CONFIG_BAUD,  "config BAUD");
    rd(C_ADDR_ATC_CONFIG_INPUT, "config input");
    rd(C_ADDR_ATC_CONFIG_G,     "config G");
    rd(C_ADDR_ATC_CONFIG_H,     "config H");
    rd(C_ADDR_ATC_DST_LEMO_A,   "destination LEMO A");
    rd(C_ADDR_ATC_DST_POKE_A,   "destination POKE A");
    rd(C_ADDR_ATC_DST_LOGIC_A,  "destination LOGIC A");
    note("written (each a different value), read back");
    wr(C_ADDR_ATC_CONFIG_UART,  x"00000014", "config UART");
    wr(C_ADDR_ATC_CONFIG_BAUD,  x"00000006", "config BAUD");
    wr(C_ADDR_ATC_CONFIG_INPUT, x"00000003", "config input");
    wr(C_ADDR_ATC_CONFIG_G,     x"00000105", "config G");
    wr(C_ADDR_ATC_CONFIG_H,     x"000003FF", "config H");
    wr(C_ADDR_ATC_DST_LEMO_A,   x"000703FF", "destination LEMO A");
    wr(C_ADDR_ATC_DST_LEMO_B,   x"000B0001", "destination LEMO B");
    wr(C_ADDR_ATC_DST_POKE_A,   x"000A0081", "destination POKE A");
    wr(C_ADDR_ATC_DST_POKE_B,   x"000B0082", "destination POKE B");
    wr(C_ADDR_ATC_DST_POKE_C,   x"000C0083", "destination POKE C");
    wr(C_ADDR_ATC_DST_POKE_D,   x"000D0084", "destination POKE D");
    wr(C_ADDR_ATC_DST_LOGIC_A,  x"FFFF0000", "destination LOGIC A");
    wr(C_ADDR_ATC_DST_LOGIC_B,  x"0000FFFF", "destination LOGIC B");
    rd(C_ADDR_ATC_CONFIG_UART,  "config UART");
    rd(C_ADDR_ATC_CONFIG_BAUD,  "config BAUD");
    rd(C_ADDR_ATC_CONFIG_INPUT, "config input");
    rd(C_ADDR_ATC_CONFIG_G,     "config G");
    rd(C_ADDR_ATC_CONFIG_H,     "config H");
    rd(C_ADDR_ATC_DST_LEMO_A,   "destination LEMO A");
    rd(C_ADDR_ATC_DST_LEMO_B,   "destination LEMO B");
    rd(C_ADDR_ATC_DST_POKE_A,   "destination POKE A");
    rd(C_ADDR_ATC_DST_POKE_B,   "destination POKE B");
    rd(C_ADDR_ATC_DST_POKE_C,   "destination POKE C");
    rd(C_ADDR_ATC_DST_POKE_D,   "destination POKE D");
    rd(C_ADDR_ATC_DST_LOGIC_A,  "destination LOGIC A");
    rd(C_ADDR_ATC_DST_LOGIC_B,  "destination LOGIC B");
    strip(count, "outputs:  config UART " & hex(cfg_uart) & " BAUD " & hex(cfg_baud)
      & " input " & hex(cfg_input) & " G " & hex(cfg_g) & " H " & hex(cfg_h));
    strip(count, "outputs:  destination LEMO A " & hex(lemo_a) & " B " & hex(lemo_b)
      & " | LOGIC A " & hex(logic_a) & " B " & hex(logic_b));
    strip(count, "outputs:  destination POKE A " & hex(dpoke_a) & " B " & hex(dpoke_b)
      & " C " & hex(dpoke_c) & " D " & hex(dpoke_d));

    note("pokes:  each a one-clock strobe with the tile mask (the low 10 bits)");
    wr(C_ADDR_ATC_POKE_A, x"00000001", "poke A:  tile 0");
    wr(C_ADDR_ATC_POKE_B, x"00000200", "poke B:  tile 9");
    wr(C_ADDR_ATC_POKE_C, x"FFFFFFFF", "poke C:  all bits (10 kept)");
    wr(C_ADDR_ATC_POKE_D, x"00000155", "poke D:  tiles 0, 2, 4, 6, 8");

    note("count requests:  a one-clock strobe with the command byte (code, chan);  COUNT reads"
      & " the answer");
    rd(C_ADDR_ATC_COUNT,     "count (before any request)");
    wr(C_ADDR_ATC_COUNT_REQ, x"00000020", "count request:  START");
    wr(C_ADDR_ATC_COUNT_REQ, x"FFFFFF63", "count request:  READ H 3 (low byte kept)");
    rd(C_ADDR_ATC_COUNT,     "count");

    note("read-only:  status and timestamp (input 1111111122222222:  the low word)");
    rd(C_ADDR_ATC_STATUS,    "status (input 0000ABCD)");
    rd(C_ADDR_ATC_TIMESTAMP, "timestamp");

    note("no ack:  write-only and read-only registers the wrong way, addresses not ATC registers");
    rd(C_ADDR_ATC_POKE_A,    "poke A");
    rd(C_ADDR_ATC_COUNT_REQ, "count request");
    wr(C_ADDR_ATC_STATUS,    x"FFFFFFFF", "status");
    wr(C_ADDR_ATC_TIMESTAMP, x"FFFFFFFF", "timestamp");
    wr(C_ADDR_ATC_COUNT,     x"FFFFFFFF", "count");
    rd(C_ADDR_ATC_TIMESTAMP + 4, "008:  the timestamp's high word, if it had one");
    reg_read(clk, rb, rbr, x"F100", "F100:  config UART's register, in the global scope");
    wait;
  end process;

  -- each clock a strobe is high (printed 2 ns later, after the write that caused it)
  strobe_process : process
    variable c : integer;
  begin
    wait until rising_edge(clk);
    c := count;
    wait for 2 ns;
    for i in 0 to 3 loop
      if poke(i) = '1' then
        strip(c, "strobe:  POKE " & character'val(character'pos('A') + i)
          & ", mask " & bits(mask(i)));
      end if;
    end loop;
    if count_req = '1' then strip(c, "strobe:  COUNT_REQ, command " & hex(count_cmd)); end if;
  end process;
end behaviour;

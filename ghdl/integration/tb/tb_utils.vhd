-- tb_utils:  small helpers for the viewing testbenches (simulation only; tb/ is never synced to vivado).
--   hex(v), bits(v or b), dec(i, w), mark(b, s):  pieces of one output line
--   print(s):     print a line (queued notes first)
--   note(s):      queue a note, printed before the next line
--   strip(c, s):  a strip line "c: <c> <s>";  after fold(true), repeats of the same s fold into one line
--                 ("... N more");  fold(false) prints any such line still pending (call it where output ends)
--   reg_write, reg_read:  one regbus access, printed as one line
library ieee;
use std.textio.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_utils is
  function hex(v : std_logic_vector) return string;           -- width a multiple of 4
  function bits(v : std_logic_vector) return string;          -- "0110"
  function bits(b : std_logic) return string;                 -- "1"
  function dec(i : integer; w : natural := 0) return string;  -- left justified, padded to w
  function mark(b : std_logic; s : string) return string;     -- " s" when b='1', else ""
  procedure print(s : string);
  procedure note(s : string);
  procedure fold(enable : boolean);
  procedure strip(c : integer; s : string);

  -- regbus:  rb driven by the testbench, rbr by the unit; connect each field to the unit's port
  type rb_t is record
    raddr, waddr     : std_logic_vector(15 downto 0);
    rupdate, wupdate : std_logic;
    wdata            : std_logic_vector(31 downto 0);
  end record;
  type rbr_t is record
    rdata      : std_logic_vector(31 downto 0);
    rack, wack : std_logic;
  end record;
  constant RB_IDLE : rb_t := (x"0000", x"0000", '0', '0', x"00000000");
  -- TX/RX register address:  scope (2 bits), chan (6 bits), register (8 bits)
  function addr(scope, chan, reg : integer) return std_logic_vector;
  procedure reg_write(signal clk : in std_logic; signal rb : out rb_t; signal rbr : in rbr_t;
                      a, d : std_logic_vector; txt : string := "");
  procedure reg_read (signal clk : in std_logic; signal rb : out rb_t; signal rbr : in rbr_t;
                      a : std_logic_vector; txt : string := "");
end package;

package body tb_utils is
  shared variable notes   : line;              -- queued notes
  shared variable last    : line;              -- text of the last strip line, for folding
  shared variable folding : boolean := false;
  shared variable folded  : natural := 0;      -- strip lines folded since the last one printed

  function hex(v : std_logic_vector) return string is         -- like hwrite:  U, X, ... show as 0
    constant DIGITS : string(1 to 16) := "0123456789ABCDEF";
    constant x      : std_logic_vector(v'length-1 downto 0) := to_stdlogicvector(to_bitvector(v));
    variable s      : string(1 to v'length/4);
  begin
    for i in s'range loop
      s(i) := DIGITS(to_integer(unsigned(x(v'length-4*i+3 downto v'length-4*i))) + 1);
    end loop;
    return s;
  end function;

  function bits(v : std_logic_vector) return string is
    constant x : std_logic_vector(1 to v'length) := v;
    variable s : string(1 to v'length);
  begin
    for i in s'range loop
      s(i) := std_logic'image(x(i))(2);         -- "'1'"
    end loop;
    return s;
  end function;

  function bits(b : std_logic) return string is
    constant s : string := std_logic'image(b);                -- "'1'"
  begin return s(2 to 2); end function;

  function dec(i : integer; w : natural := 0) return string is
    constant s : string := integer'image(i);
  begin
    if s'length >= w then return s; end if;
    return s & (1 to w - s'length => ' ');
  end function;

  function mark(b : std_logic; s : string) return string is
  begin
    if b = '1' then return " " & s; end if;
    return "";
  end function;

  procedure flush_fold is
    variable l : line;
  begin
    if folded > 0 then write(l, "        ... " & dec(folded) & " more"); writeline(output, l); folded := 0; end if;
  end procedure;

  procedure print(s : string) is
    variable l : line;
  begin
    flush_fold;
    if notes /= null then writeline(output, notes); deallocate(notes); end if;
    deallocate(last);
    write(l, s); writeline(output, l);
  end procedure;

  procedure note(s : string) is
  begin
    if notes /= null then write(notes, LF); end if;
    write(notes, "-- " & s);
  end procedure;

  procedure fold(enable : boolean) is
  begin
    if not enable then flush_fold; end if;
    folding := enable;
  end procedure;

  procedure strip(c : integer; s : string) is
  begin
    if folding and notes = null and last /= null then
      if last.all = s then folded := folded + 1; return; end if;
    end if;
    print("c: " & dec(c, 6) & s);
    last := new string'(s);
  end procedure;

  function addr(scope, chan, reg : integer) return std_logic_vector is
  begin return std_logic_vector(to_unsigned((scope * 64 + chan) * 256 + reg, 16)); end function;

  -- each access starts 1 ns after a clock edge, once any earlier ack is low; drives for one clock,
  -- then samples the ack 1 ns after each edge (up to 100 clocks)
  procedure reg_write(signal clk : in std_logic; signal rb : out rb_t; signal rbr : in rbr_t;
                      a, d : std_logic_vector; txt : string := "") is
  begin
    loop wait until rising_edge(clk); wait for 1 ns; exit when rbr.wack = '0'; end loop;
    rb <= (raddr => x"0000", rupdate => '0', waddr => a, wdata => d, wupdate => '1');
    for i in 0 to 100 loop
      wait until rising_edge(clk); wait for 1 ns; rb <= RB_IDLE;
      exit when rbr.wack = '1';
    end loop;
    print("W " & hex(a) & " <- " & hex(d) & mark(not rbr.wack, "NO ACK") & "  " & txt);
  end procedure;

  procedure reg_read(signal clk : in std_logic; signal rb : out rb_t; signal rbr : in rbr_t;
                     a : std_logic_vector; txt : string := "") is
  begin
    loop wait until rising_edge(clk); wait for 1 ns; exit when rbr.rack = '0'; end loop;
    rb <= (raddr => a, rupdate => '1', waddr => x"0000", wdata => x"00000000", wupdate => '0');
    for i in 0 to 100 loop
      wait until rising_edge(clk); wait for 1 ns; rb <= RB_IDLE;
      exit when rbr.rack = '1';
    end loop;
    print("R " & hex(a) & " -> " & hex(rbr.rdata) & mark(not rbr.rack, "NO ACK") & "  " & txt);
  end procedure;
end package body;

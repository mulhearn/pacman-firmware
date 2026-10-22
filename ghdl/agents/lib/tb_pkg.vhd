-- tb_pkg:  helpers for the checks and waveform testbenches in ghdl/agents (simulation only, never synced)
--
-- Clock and formatting:  clock, hex, dec, flag, print.
-- For the checks (ghdl/agents/check/, run by "make check" in ghdl/agents): check,
-- check_equal and finish.  Each check counts; finish prints one line,
--   PASS <name> (<n> checks)    or    FAIL <name> (<k> of <n> checks failed)
-- and on failure stops the simulation with severity failure (non-zero exit).
library ieee;
use std.textio.all;
use ieee.std_logic_1164.all;

package tb_pkg is
  -- free-running clock; count = number of rising edges so far (1 at t=0)
  procedure clock(signal clk : out std_logic; signal count : out integer; constant period : time := 10 ns);
  -- clock that stops once done is true, so a unit test ends by itself
  procedure clock_until(signal clk : out std_logic; signal done : in boolean; constant period : time := 10 ns);
  -- formatting for ascii dumps:  "0x" & hex(v),  dec(i, width)
  function hex(v : std_logic_vector) return string;   -- 'X' for any nibble holding U/X/Z/...
  function dec(i : integer; w : natural := 0) return string;  -- left justified, padded to w
  function flag(b : std_logic; s : string) return string;     -- s when b='1', else ""
  procedure print(s : string);
  -- self-check:  error (with simulation time) when cond is false
  procedure check(cond : boolean; msg : string);
  -- error showing both values (hex) when actual /= expected (any U/X/Z fails)
  procedure check_equal(actual, expected : std_logic_vector; msg : string);
  procedure check_equal(actual, expected : std_logic; msg : string);
  procedure check_equal(actual, expected : integer; msg : string);
  -- the requirement (docs/requirements.txt, level 2) the following checks count toward, until the next req
  procedure req(id : string);
  -- result line for "make check", and one "REQ <id> <checks> <failures>" line per requirement;
  -- call once at the end of the test
  procedure finish(name : string);
end package;

package body tb_pkg is
  shared variable checks   : natural := 0;
  shared variable failures : natural := 0;

  -- tallies per requirement;  entry 0 counts the checks made before any req
  constant MAX_REQ : natural := 63;
  subtype req_id_t is string(1 to 12);
  type req_ids_t is array (0 to MAX_REQ) of req_id_t;
  type req_counts_t is array (0 to MAX_REQ) of natural;
  shared variable req_ids    : req_ids_t := (0 => "(none)      ", others => (others => ' '));
  shared variable req_checks : req_counts_t := (others => 0);
  shared variable req_fails  : req_counts_t := (others => 0);
  shared variable req_n      : natural := 0;    -- entries 1 .. req_n in use
  shared variable req_now    : natural := 0;

  procedure clock(signal clk : out std_logic; signal count : out integer; constant period : time := 10 ns) is
    variable n : integer := 0;
  begin
    loop
      n := n + 1;
      count <= n;
      clk <= '1';
      wait for period/2;
      clk <= '0';
      wait for period/2;
    end loop;
  end procedure;

  procedure clock_until(signal clk : out std_logic; signal done : in boolean; constant period : time := 10 ns) is
  begin
    while not done loop
      clk <= '1';
      wait for period/2;
      clk <= '0';
      wait for period/2;
    end loop;
    wait;
  end procedure;

  function hex(v : std_logic_vector) return string is
    constant N     : natural := (v'length + 3) / 4;
    constant DIGIT : string(1 to 16) := "0123456789ABCDEF";
    variable x     : std_logic_vector(4*N-1 downto 0) := (others => '0');
    variable s     : string(1 to N);
    variable d     : natural;
  begin
    x(v'length-1 downto 0) := v;
    for i in 0 to N-1 loop
      d := 0;
      for b in 3 downto 0 loop
        case x(4*(N-1-i) + b) is
          when '1' | 'H' => d := 2*d + 1;
          when '0' | 'L' => d := 2*d;
          when others    => d := 16;  exit;
        end case;
      end loop;
      if d = 16 then s(i+1) := 'X'; else s(i+1) := DIGIT(d+1); end if;
    end loop;
    return s;
  end function;

  function dec(i : integer; w : natural := 0) return string is
    constant s : string := integer'image(i);
  begin
    if s'length >= w then return s; end if;
    return s & (1 to w - s'length => ' ');
  end function;

  function flag(b : std_logic; s : string) return string is
  begin
    if b = '1' then return s; end if;
    return "";
  end function;

  procedure print(s : string) is
    variable l : line;
  begin
    write(l, s);
    writeline(output, l);
  end procedure;

  procedure req(id : string) is
    variable padded : req_id_t := (others => ' ');
  begin
    padded(1 to id'length) := id;
    for i in 1 to req_n loop
      if req_ids(i) = padded then
        req_now := i;
        return;
      end if;
    end loop;
    assert req_n < MAX_REQ report "tb_pkg:  too many requirements" severity failure;
    req_n := req_n + 1;
    req_ids(req_n) := padded;
    req_now := req_n;
  end procedure;

  procedure check(cond : boolean; msg : string) is
  begin
    checks := checks + 1;
    req_checks(req_now) := req_checks(req_now) + 1;
    if not cond then
      failures := failures + 1;
      req_fails(req_now) := req_fails(req_now) + 1;
    end if;
    assert cond report msg severity error;
  end procedure;

  procedure check_equal(actual, expected : std_logic_vector; msg : string) is
    variable a : std_logic_vector(actual'length-1 downto 0) := actual;
    variable e : std_logic_vector(expected'length-1 downto 0) := expected;
    variable ok : boolean := a'length = e'length;
  begin
    if ok then
      for i in a'range loop
        if not ((a(i) = '0' and e(i) = '0') or (a(i) = '1' and e(i) = '1') or e(i) = '-') then
          ok := false;
        end if;
      end loop;
    end if;
    check(ok, msg & ": got 0x" & hex(actual) & ", expected 0x" & hex(expected));
  end procedure;

  procedure check_equal(actual, expected : std_logic; msg : string) is
  begin
    check(actual = expected, msg & ": got " & std_logic'image(actual) & ", expected " & std_logic'image(expected));
  end procedure;

  procedure check_equal(actual, expected : integer; msg : string) is
  begin
    check(actual = expected, msg & ": got " & integer'image(actual) & ", expected " & integer'image(expected));
  end procedure;

  procedure finish(name : string) is
  begin
    for i in 0 to req_n loop
      if req_checks(i) > 0 then
        print("REQ " & req_ids(i) & " " & integer'image(req_checks(i)) & " " & integer'image(req_fails(i)));
      end if;
    end loop;
    if failures = 0 then
      print("PASS " & name & " (" & integer'image(checks) & " checks)");
    else
      print("FAIL " & name & " (" & integer'image(failures) & " of " & integer'image(checks) & " checks failed)");
      report name & ": " & integer'image(failures) & " failed checks" severity failure;
    end if;
  end procedure;
end package body;

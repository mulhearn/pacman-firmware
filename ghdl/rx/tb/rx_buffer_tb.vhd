----------------------------------------------------------------------------------------------------
-- rx_buffer_tb:  RX buffer test bench
--
-- Round-robin streaming of the 44 RX channels to AXI:  up to the maximum number of words per
-- packet, then the trailer (end-of-packet header L with the word count) on TLAST;  again until
-- every channel is drained.  Channels whose data is EE.. are the unlabelled ones.
--
-- Shows one line per clock: state, t = turn (channel), w = fragment (0-2) of the turn, valid/ready
-- of channels 0-2, valid = channels still holding data | tv = tvalid, tdata, the word type as a
-- character on headers, (BEAT) each beat taken, (TLAST) the last.
--
-- Scenario: at most 3 words per packet, no timeout;  every channel gets valid data at once at 500
-- ns:  the words come out in channel order, across packets  -- (alternatives in comments, e.g.
-- channels 0-2 valid again as soon as taken:  each packet resumes at the next channel, so the higher
-- channels still get their turns)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity rx_buffer_tb is
end rx_buffer_tb;

architecture behaviour of rx_buffer_tb is
  signal count       : integer := 0;
  signal clk         : std_logic;
  signal rst         : std_logic;
  signal tdata       : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0);
  signal tvalid      : std_logic;
  signal tready      : std_logic := '1';
  signal tlast       : std_logic;
  signal chan_select : std_logic_vector(C_SELECT_WIDTH-1 downto 0);
  signal header      : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0) := (others => '0');
  signal frag_a      : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0) := (others => '0');
  signal frag_b      : std_logic_vector(C_RX_AXIS_WIDTH-1 downto 0) := (others => '0');
  signal uvalid      : std_logic_vector(C_RX_NUM_CHAN-1 downto 0);
  signal uready      : std_logic_vector(C_RX_NUM_CHAN-1 downto 0);
  signal status      : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal config     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal eop_header : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal refill     : std_logic_vector(C_RX_NUM_CHAN-1 downto 0);
begin
  -- the buffer configuration (alternatives in comments):
  config     <= x"00030000";                                    -- 3 words per packet, no timeout
  --config     <= x"00010000";                                  -- 1 word per packet, no timeout
  --config     <= x"00050000";                                  -- 5 words per packet, no timeout
  eop_header <= x"1100004C";                                    -- end-of-packet header (type L)
  -- the input (alternatives in comments):
  refill     <= (others => '0');                                -- every channel valid once
  --refill     <= (2 downto 0 => '1', others => '0');           -- channels 0-2 valid again as soon as taken

  uut: entity work.rx_buffer port map (
    CLK_I         => clk,
    RST_I         => rst,
    M_AXIS_TDATA  => tdata,
    M_AXIS_TVALID => tvalid,
    M_AXIS_TREADY => tready,
    M_AXIS_TLAST  => tlast,
    STATUS_O      => status,
    CONFIG_I      => config,
    CHAN_SELECT_O => chan_select,
    HEADER_I      => header,
    FRAG_A_I      => frag_a,
    FRAG_B_I      => frag_b,
    VALID_I       => uvalid,
    READY_O       => uready,
    EOP_HEADER_I  => eop_header,
    M_AXIS_TKEEP  => open,
    DEBUG_O       => open
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

  -- every 500 ns:  all channels valid at once;  each clears when the buffer takes it (ready), unless
  -- refilled
  uvalid_process : process
  begin
    uvalid <= (others => '0');
    wait for 500 ns;
    note("every channel valid");
    uvalid <= (others => '1');
    loop
      wait for 10 ns;
      uvalid <= (uvalid and (not uready)) or refill;
      exit when unsigned((uvalid and (not uready)) or refill) = 0;
    end loop;
  end process;

  -- the data on the selected channel:  a recognisable header (channel byte, word type) for a few channels,
  -- EE.. for the others
  data_process : process
    variable h : std_logic_vector(15 downto 0);
  begin
    wait for 10 ns;
    case to_integer(unsigned(chan_select)) is
      when 0      => h := x"0144";
      when 2      => h := x"0244";
      when 5      => h := x"0943";
      when 8      => h := x"0A44";
      when 10     => h := x"0B44";
      when 11     => h := x"0C44";
      when 42     => h := x"2B44";
      when 43     => h := x"2C44";
      when others => h := x"EE44";
    end case;
    header <= x"000000000000" & h;
    if h = x"EE44" then
      frag_a <= x"00000000EEEEEEEE";
      frag_b <= x"00000000EEEEEEEE";
    else
      frag_a <= x"0000000001598762";
      frag_b <= x"000000002244BBBB";
    end if;
  end process;

  output_process : process
    type names_t is array (0 to 3) of string(1 to 4);
    constant STATE : names_t := ("IDLE", "WAIT", "STRM", "TAIL");
    variable n     : integer;
    variable wtype : character;
  begin
    fold(true);
    while count < 100 loop
      wait for 10 ns;
      if count >= 50 then
        n := 0;
        for i in uvalid'range loop
          if uvalid(i) = '1' then n := n + 1; end if;
        end loop;
        wtype := ' ';
        if tvalid = '1' and status(15 downto 14) = "01" then
          wtype := character'val(to_integer(unsigned(tdata(7 downto 0))));
        end if;
        strip(count, STATE(to_integer(unsigned(status(1 downto 0))))
              & " t " & dec(to_integer(unsigned(status(13 downto 8))), 2) & " w " & dec(to_integer(unsigned(status(15 downto 14))))
              & " | ch0 " & bits(uvalid(0) & uready(0)) & " ch1 " & bits(uvalid(1) & uready(1)) & " ch2 " & bits(uvalid(2) & uready(2))
              & " | valid " & dec(n, 2) & " | tv " & bits(tvalid) & " " & hex(tdata) & " " & wtype
              & mark(tvalid and tready, "(BEAT)") & mark(tlast, "(TLAST)") & mark(rst, "(RESET)"));
      end if;
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

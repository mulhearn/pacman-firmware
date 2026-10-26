----------------------------------------------------------------------------------------------------
-- tx_buffer_tb:  TX buffer test bench
--
-- One DMA packet in over AXI stream, out to the 40 UART buffers:  every valid bit is set and the
-- data latched after TLAST;  the valid bits clear when taken.
--
-- Shows one line per clock: state | tdata (low 16 bits), vr = tvalid tready, (BEAT) beat taken,
-- (TLAST) the last | valid = the 40 UART valid bits | udata = the data of UARTs 0-3 (low 12 bits).
--
-- Scenario: 41 beats:  header = channel mask (all 40 UARTs), then one word per UART,
-- DDDDDDiiCCCCCCii;  all UARTs take their word at 460 ns
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity tx_buffer_tb is
end tx_buffer_tb;

architecture behaviour of tx_buffer_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal tdata  : std_logic_vector(C_TX_AXIS_WIDTH-1 downto 0) := (others => '0');
  signal tvalid : std_logic := '0';
  signal tready : std_logic;
  signal tlast  : std_logic := '0';
  signal status : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal udata  : uart_data_array_t;
  signal uvalid : std_logic_vector(C_NUM_UART-1 downto 0);
  signal uready : std_logic_vector(C_NUM_UART-1 downto 0);
begin
  uut: entity work.tx_buffer port map (
    CLK_I         => clk,
    RST_I         => rst,
    S_AXIS_TDATA  => tdata,
    S_AXIS_TVALID => tvalid,
    S_AXIS_TREADY => tready,
    S_AXIS_TKEEP  => (others=>'1'),
    S_AXIS_TLAST  => tlast,
    DATA_O        => udata,
    VALID_O       => uvalid,
    READY_I       => uready,
    DEBUG_O       => status,
    STATUS_O      => open
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

  ready_process : process
  begin
    uready <= (others => '0');
    wait for 461 ns;
    note("READY from every UART (one clock)");
    uready <= (others => '1');
    wait for 10 ns;
    uready <= (others => '0');
    wait;
  end process;

  stream_process : process
  begin
    tvalid <= '0';
    tlast  <= '0';
    wait for 21 ns;
    note("AXI stream:  41 beats, the header (channel mask) and one word per UART");
    tvalid <= '1';
    tdata  <= x"000000FFFFFFFFFF";
    wait for 10 ns;
    for i in 0 to C_NUM_UART-1 loop
      tdata <= x"DDDDDD" & std_logic_vector(to_unsigned(i, 8)) & x"CCCCCC" & std_logic_vector(to_unsigned(i, 8));
      if i = C_NUM_UART-1 then tlast <= '1'; end if;
      wait for 10 ns;
    end loop;
    tvalid <= '0';
    tdata  <= (others => '0');
    tlast  <= '0';
    wait;
  end process;

  output_process : process
    type names_t is array (0 to 3) of string(1 to 3);
    constant STATE : names_t := ("IDL", "STR", "TX ", "???");
  begin
    fold(true);
    while count < 60 loop
      wait for 10 ns;
      strip(count, STATE(to_integer(unsigned(status(9 downto 8))))
            & " | tdata ..." & hex(tdata(15 downto 0)) & " vr " & bits(tvalid & tready) & mark(tvalid and tready, "(BEAT)")
            & mark(tlast, "(TLAST)") & " | valid " & hex(uvalid)
            & " | udata 0:" & hex(udata(0)(11 downto 0)) & " 1:" & hex(udata(1)(11 downto 0))
            & " 2:" & hex(udata(2)(11 downto 0)) & " 3:" & hex(udata(3)(11 downto 0)) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

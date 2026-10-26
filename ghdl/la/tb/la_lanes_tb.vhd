----------------------------------------------------------------------------------------------------
-- la_lanes_tb:  logic analyzer lanes test bench
--
-- The inputs pass two input registers, the lanes and the final mux:  a sample holds the inputs of
-- four clocks before, all from the same clock (ts);  the strobe comes with its sample.
--
-- Shows one line per clock: n = the input count | se = the sample strobe | sample (hex), nibble H
-- first | ts = its timestamp.
--
-- Scenario: POSI of every tile = n (each tile's 4 POSI lines);  lane A on tile 2, lane B on tile 9;
-- mux:  A TILE_A_POSI, B TILE_B_POSI, C TILE_AB_GH, D ATC_STATUS_LOWER (UCLK, BAUD), rest ZERO;
-- every 2nd clock  -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity la_lanes_tb is
end la_lanes_tb;

architecture behaviour of la_lanes_tb is
  signal count   : integer := 0;
  signal clk     : std_logic;
  signal rst     : std_logic;
  signal n       : unsigned(3 downto 0) := (others => '0');
  signal posi    : std_logic_vector(C_NUM_UART-1 downto 0);
  signal g, h    : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal baud    : std_logic;
  signal atc     : std_logic_vector(C_STATUS_BITS-1 downto 0);
  signal ts      : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
  signal tile    : std_logic_vector(4*4-1 downto 0);
  signal mux_select : std_logic_vector(8*5-1 downto 0);
  signal period  : std_logic_vector(31 downto 0);
  signal phase   : std_logic_vector(31 downto 0);
  signal lock    : std_logic;
  signal sample  : std_logic_vector(31 downto 0);
  signal se      : std_logic;
  signal ts_out  : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
begin
  -- the lanes configuration (alternatives in comments):
  tile   <= x"0092";                                            -- A tile 2, B tile 9, C, D tile 0
  --tile   <= x"00FA";                                          -- A tile 10, B tile 15:  zeros
  mux_select <= "00000" & "00000" & "00000" & "00000" & "01011" & "01001" & "00100" & "00010";  -- H to A
  --mux_select <= "00000" & "00000" & "00000" & "00000" & "00000" & "00000" & "00000" & "00010";  -- A only
  period <= x"00000002";                                        -- every 2nd clock
  --period <= x"00000001";                                      -- every clock
  phase  <= x"00000000";
  lock   <= '0';                                                -- free running
  --lock   <= '1';                                              -- BAUD locked, PHASE 0

  uut: entity work.la_lanes port map (
    CLK_I        => clk,
    RST_I        => rst,
    PISO_I       => (others => '0'),
    POSI_I       => posi,
    G_I          => g,
    H_I          => h,
    BAUD_I       => baud,
    ATC_STATUS_I => atc,
    RX_STATUS_I  => (others => '0'),
    TX_STATUS_I  => (others => '0'),
    TIMESTAMP_I  => ts,
    TILE_I       => tile,
    MUX_SELECT_I => mux_select,
    PERIOD_I     => period,
    PHASE_I      => phase,
    LOCK_I       => lock,
    SAMPLE_O     => sample,
    SE_O         => se,
    TS_O         => ts_out
  );

  clk_process : process
  begin
    count <= count + 1;
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  rst_process : process
  begin
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;

  -- the inputs, changed on falling edges
  input_process : process(clk)
  begin
    if falling_edge(clk) then
      n <= n + 1;
    end if;
  end process;
  posi_tiles: for t in 0 to C_NUM_TILE-1 generate
    posi(4*t+3 downto 4*t) <= std_logic_vector(n);
  end generate;
  g    <= (2 => n(0), others => '0');                           -- G of tile 2 = n(0)
  h    <= (9 => n(1), others => '0');                           -- H of tile 9 = n(1)
  baud <= '1' when n = 0 else '0';
  atc  <= "000000" & baud & n(0);
  ts   <= std_logic_vector(resize(n, C_TIMESTAMP_WIDTH));

  output_process : process
  begin
    while count < 24 loop
      wait for 10 ns;
      strip(count, "n " & hex(std_logic_vector(n)) & " | se " & bits(se) & " | sample " & hex(sample) &
            " | ts " & hex(ts_out(15 downto 0)) & mark(rst, "(RESET)"));
    end loop;
    wait;
  end process;
end behaviour;

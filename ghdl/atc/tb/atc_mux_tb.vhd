----------------------------------------------------------------------------------------------------
-- atc_mux_tb:  ATC multiplexer test bench
--
-- Route the ATC sources to the per-tile outputs G and H (and the markers M) by their destination
-- registers.  The pokes reach G and H two clocks later, LEMO B reaches M one clock later.
--
-- Shows one line per clock: lemo a, b | poke c, d | g, h (10 tiles), m (markers).
--
-- Scenario: POKE C (all tiles) to G, POKE D (all tiles) to H, LEMO B to G and marker 0; clock 20 ns
-- -- (alternatives in comments)
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.common.all;
use work.tb_utils.all;

entity atc_mux_tb is
end atc_mux_tb;

architecture behaviour of atc_mux_tb is
  signal count  : integer := 0;
  signal clk    : std_logic;
  signal rst    : std_logic;
  signal lemo_a : std_logic := '0';
  signal lemo_b : std_logic;
  signal poke_c : std_logic;
  signal poke_d : std_logic;
  signal h      : std_logic_vector(9 downto 0) := (others => '0');
  signal g      : std_logic_vector(9 downto 0) := (others => '0');
  signal m      : std_logic_vector(3 downto 0) := (others => '0');
  signal mask_c     : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal mask_d     : std_logic_vector(C_NUM_TILE-1 downto 0);
  signal dst_poke_c : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal dst_poke_d : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal dst_lemo_b : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
begin
  -- the routing configuration (alternatives in comments):
  mask_c     <= "1111111111";                                   -- POKE C mask:  all tiles
  --mask_c     <= "0000011111";                                 -- POKE C mask:  tiles 0-4
  mask_d     <= "1111111111";                                   -- POKE D mask:  all tiles
  --mask_d     <= "0000011111";                                 -- POKE D mask:  tiles 0-4
  dst_poke_c <= x"0002FFC1";                                    -- POKE C:  G of all tiles, 2 clocks
  --dst_poke_c <= x"000207C1";                                  -- POKE C:  G of tiles 0-4, 2 clocks
  --dst_poke_c <= x"0002FFC3";                                  -- POKE C:  G+H all tiles, 2 clocks
  dst_poke_d <= x"0003FFC2";                                    -- POKE D:  H of all tiles, 3 clocks
  --dst_poke_d <= x"0006FFC2";                                  -- POKE D:  H of all tiles, 6 clocks
  dst_lemo_b <= x"0008FFC5";                                    -- LEMO B:  G all, marker 0, 8 clk
  --dst_lemo_b <= x"00080004";                                  -- LEMO B:  marker 0 only, 8 clocks

  uut: entity work.atc_mux port map (
    CLK_I         => clk,
    RST_I         => rst,
    LEMO_A_I      => lemo_a,
    LEMO_B_I      => lemo_b,
    POKE_A_I      => '0',
    POKE_B_I      => '0',
    POKE_C_I      => poke_c,
    POKE_D_I      => poke_d,
    LOGIC_A_I     => '0',
    LOGIC_B_I     => '0',
    MASK_A_I      => (others => '0'),
    MASK_B_I      => (others => '0'),
    MASK_C_I      => mask_c,
    MASK_D_I      => mask_d,
    DST_LEMO_A_I  => x"00000000",
    DST_LEMO_B_I  => dst_lemo_b,
    DST_POKE_A_I  => x"00000000",
    DST_POKE_B_I  => x"00000000",
    DST_POKE_C_I  => dst_poke_c,
    DST_POKE_D_I  => dst_poke_d,
    DST_LOGIC_A_I => x"00000000",
    DST_LOGIC_B_I => x"00000000",
    G_O           => g,
    H_O           => h,
    M_O           => m
  );

  clk_process : process
  begin
    count <= count + 1;
    clk <= '1';
    wait for 10 ns;
    clk <= '0';
    wait for 10 ns;
  end process;

  rst_process : process
  begin
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;

  stimulus_process : process
  begin
    lemo_b <= '0';
    poke_c <= '0';
    poke_d <= '0';
    wait for 21 ns;
    poke_c <= '1'; wait for 30 ns;
    poke_c <= '0'; poke_d <= '1'; wait for 20 ns;
    poke_d <= '0'; wait for 30 ns;
    lemo_b <= '1'; wait for 20 ns;
    lemo_b <= '0';
    wait;
  end process;

  output_process : process
  begin
    fold(true);
    while count < 100 loop
      wait for 20 ns;
      strip(count, "lemo a " & bits(lemo_a) & " b " & bits(lemo_b) & " | poke c " & bits(poke_c) & " d " & bits(poke_d)
            & " | g " & bits(g) & " h " & bits(h) & " m " & bits(m) & mark(rst, "(RESET)"));
    end loop;
    fold(false);
    wait;
  end process;
end behaviour;

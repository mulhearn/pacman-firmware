library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

entity atc_mux is
  generic (
    constant C_CONFIG_WIDTH     : integer := 32;
    constant C_NUM_TILE         : integer := 10
  );

  port (
    --clock and active-high reset:
    CLK_I	: in  std_logic;
    RST_I	: in  std_logic;

    --Input stimuli: one-clock cycle long active high pulses. LEMO is
    --from front-panel, POKEs are register writes from the PS, LOGIC is
    --from the logic unit.
    LEMO_A_I	: in  std_logic;
    LEMO_B_I	: in  std_logic;
    POKE_A_I	: in  std_logic;
    POKE_B_I	: in  std_logic;
    POKE_C_I	: in  std_logic;
    POKE_D_I	: in  std_logic;
    LOGIC_A_I	: in  std_logic;
    LOGIC_B_I	: in  std_logic;

    -- Transient tile masks: each POKE (register write) carries a
    -- tag-along mask applicable to that poke only. LEMO/LOGIC have no
    -- mask (LEMO is a physical input, LOGIC omitted for simplicity).
    MASK_A_I    : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    MASK_B_I    : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    MASK_C_I    : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    MASK_D_I    : in  std_logic_vector(C_NUM_TILE-1 downto 0);

    --Configuration:  each stimulus has a destination configuration, detailing
    -- how and where it should be forwarded:
    -- MSB: DDDD DDDD DDDD DDDD TTTT TTTT TTMM MMGH LSB
    -- G(0) = enable G, H(0) = enable H
    -- T(0-9) tile mask for G/H outputs, e.g. T(0) = TILE 1, T(1) = TILE 2, ...
    -- M(0-4) marker enables, direct (no separate mask)
    -- D(0-15) pulse duration in clk cycles (maximum 65535 clock cycles)
    DST_LEMO_A_I  : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_LEMO_B_I  : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_POKE_A_I  : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_POKE_B_I  : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_POKE_C_I  : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_POKE_D_I  : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_LOGIC_A_I : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DST_LOGIC_B_I : in std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

    --output
    G_O     : out std_logic_vector(9 downto 0) := (others => '0');
    H_O     : out std_logic_vector(9 downto 0) := (others => '0');
    M_O     : out std_logic_vector(C_NUM_MARKER-1 downto 0)
  );
end;

architecture behavioral of atc_mux is
  type config_arr is array (0 to 7) of std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  type cnt_arr is array (0 to 7) of unsigned(15 downto 0); --counter of duration
  signal clk             : std_logic;
  signal rst             : std_logic;
  signal output_g        : std_logic_vector(9 downto 0);
  signal output_h        : std_logic_vector(9 downto 0);
  signal output_m        : std_logic_vector(C_NUM_MARKER-1 downto 0);
  signal sel_g           : std_logic_vector(7 downto 0);
  signal sel_h           : std_logic_vector(7 downto 0);

  signal config          : config_arr;

  signal mask_a          : std_logic_vector(C_NUM_TILE-1 downto 0):= (others => '0');
  signal mask_b          : std_logic_vector(C_NUM_TILE-1 downto 0):= (others => '0');
  signal mask_c          : std_logic_vector(C_NUM_TILE-1 downto 0):= (others => '0');
  signal mask_d          : std_logic_vector(C_NUM_TILE-1 downto 0):= (others => '0');
  signal input_ext       : std_logic_vector(7 downto 0) := (others => '0'); --extend window for 8 inputs
  signal cnt             : cnt_arr := (others => (others => '0'));
  signal update_vec      : std_logic_vector(7 downto 0);
begin
  clk            <= CLK_I;
  rst            <= RST_I;

  update_vec <= (
    0 => LEMO_A_I,
    1 => LEMO_B_I,
    2 => POKE_A_I,
    3 => POKE_B_I,
    4 => POKE_C_I,
    5 => POKE_D_I,
    6 => LOGIC_A_I,
    7 => LOGIC_B_I
  );

  config   <= (
    0 => DST_LEMO_A_I,
    1 => DST_LEMO_B_I,
    2 => DST_POKE_A_I,
    3 => DST_POKE_B_I,
    4 => DST_POKE_C_I,
    5 => DST_POKE_D_I,
    6 => DST_LOGIC_A_I,
    7 => DST_LOGIC_B_I
  );

  --determine the enabled output ports for each stimulus:
  gen_port : for i in 0 to 7 generate
  begin
    sel_g(i) <= config(i)(0);
    sel_h(i) <= config(i)(1);
  end generate;

  -- extend input signal
  gen_input_ext : for j in 0 to 7 generate
    input_ext(j) <= '1' when cnt(j) > 0 else '0';
  end generate;


  -- reset duration counters for stimuli, and latch masks for pokes:
  process (clk, rst)
  begin
    if rst = '1' then
      for j in 0 to 7 loop
        cnt(j) <= (others => '0');
      end loop;
      mask_a <= (others => '0');
      mask_b <= (others => '0');
      mask_c <= (others => '0');
      mask_d <= (others => '0');
    elsif rising_edge(clk) then
      if update_vec(2) = '1' then
        mask_a        <= MASK_A_I;
      end if;

      if update_vec(3) = '1' then
        mask_b        <= MASK_B_I;
      end if;

      if update_vec(4) = '1' then
        mask_c        <= MASK_C_I;
      end if;

      if update_vec(5) = '1' then
        mask_d        <= MASK_D_I;
      end if;

      for j in 0 to 7 loop
        if update_vec(j) = '1' then
          cnt(j) <= unsigned( config(j)(31 downto 16) );
        elsif cnt(j) > 0 then
          cnt(j) <= cnt(j) - 1;
        end if;
      end loop;
    end if;
  end process;

  gen_g : for i in 0 to C_NUM_TILE-1 generate
  begin
    output_g(i) <=
      (sel_g(0) and input_ext(0) and config(0)(6+i)) or
      (sel_g(1) and input_ext(1) and config(1)(6+i)) or
      (sel_g(2) and input_ext(2) and config(2)(6+i) and mask_a(i)) or
      (sel_g(3) and input_ext(3) and config(3)(6+i) and mask_b(i)) or
      (sel_g(4) and input_ext(4) and config(4)(6+i) and mask_c(i)) or
      (sel_g(5) and input_ext(5) and config(5)(6+i) and mask_d(i)) or
      (sel_g(6) and input_ext(6) and config(6)(6+i)) or
      (sel_g(7) and input_ext(7) and config(7)(6+i));
  end generate;

  gen_h : for i in 0 to C_NUM_TILE-1 generate
  begin
    output_h(i) <=
      (sel_h(0) and input_ext(0) and config(0)(6+i)) or
      (sel_h(1) and input_ext(1) and config(1)(6+i)) or
      (sel_h(2) and input_ext(2) and config(2)(6+i) and mask_a(i)) or
      (sel_h(3) and input_ext(3) and config(3)(6+i) and mask_b(i)) or
      (sel_h(4) and input_ext(4) and config(4)(6+i) and mask_c(i)) or
      (sel_h(5) and input_ext(5) and config(5)(6+i) and mask_d(i)) or
      (sel_h(6) and input_ext(6) and config(6)(6+i)) or
      (sel_h(7) and input_ext(7) and config(7)(6+i));
  end generate;

  gen_m : for i in 0 to C_NUM_MARKER-1 generate
  begin
    output_m(i) <=
      (update_vec(0) and config(0)(2+i)) or
      (update_vec(1) and config(1)(2+i)) or
      (update_vec(2) and config(2)(2+i)) or
      (update_vec(3) and config(3)(2+i)) or
      (update_vec(4) and config(4)(2+i)) or
      (update_vec(5) and config(5)(2+i)) or
      (update_vec(6) and config(6)(2+i)) or
      (update_vec(7) and config(7)(2+i));
  end generate;

  process(clk,rst)
  begin
    if rst = '1' then
      G_O  <= (others => '0');
      H_O  <= (others => '0');
      M_O  <= (others => '0');
    elsif (rising_edge(clk)) then
      G_O  <= output_g;
      H_O  <= output_h;
      M_O  <= output_m;
    end if;
  end process;

end;



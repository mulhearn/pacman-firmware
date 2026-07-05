library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- pattern:  config-driven generator of a fake UART stream
--
-- Repeatedly transmits a fixed-width payload (start bit / payload /
-- stop bit) with a configurable idle count between transmissions,
-- then repeats.  PATTERN_O idles high.  Bit 0 of PAYLOAD_I is
-- transmitted first.
--

entity pattern is
  port (
    CLK_I           : in  std_logic;
    RST_I           : in  std_logic;
    BAUD_I     : in  std_logic;
    PAYLOAD_I       : in  std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
    CONFIG_I        : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DELAY_I         : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    PATTERN_O       : out std_logic;
    STATUS_O        : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
  );
end;

architecture behavioral of pattern is
  signal clk : std_logic;
  signal rst : std_logic;

  -- config fields
  alias cfg_phase : std_logic_vector(7 downto 0) is CONFIG_I(7 downto 0);
  alias cfg_mode  : std_logic_vector(3 downto 0) is CONFIG_I(11 downto 8);

  constant C_MODE_ON : std_logic_vector(3 downto 0) := "0001";

  -- baud phase counter and sample enable
  signal clk_en : std_logic;

  -- FSM
  type pattern_state_t is (IDLE, START, DATA, STOP);
  signal state : pattern_state_t;

  -- shift register for outgoing bits
  signal shift_reg : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);

  -- idle countdown, (re)loaded from DELAY_I on entry to IDLE
  signal delay_count : unsigned(C_RB_DATA_WIDTH-1 downto 0);

  -- registered output
  signal tx : std_logic := '1';

  -- status flags: pulse for one cycle, counted externally
  signal start_flag  : std_logic := '0';
  signal stop_flag   : std_logic := '0';

  -- status register
  signal status : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

begin
  clk <= CLK_I;
  rst <= RST_I;
  PATTERN_O <= tx;

  -- generate clk_en by counting from BAUD_I to cfg_phase
  process(clk, rst)
    variable count : unsigned(7 downto 0);
  begin
    if (rst='1') then
      count  := (others => '0');
      clk_en <= '0';
    elsif rising_edge(clk) then
      if BAUD_I = '1' then
        count := (others => '0');
      else
        count := count + 1;
      end if;

      if count = unsigned(cfg_phase) then
        clk_en <= '1';
      else
        clk_en <= '0';
      end if;
    end if;
  end process;

  -- state determination
  process(clk, rst)
    variable bit_counter : integer range 0 to C_UART_DATA_WIDTH-1;
  begin
    if rst = '1' then
      state       <= IDLE;
      bit_counter := 0;
      delay_count <= (others => '0');
    elsif rising_edge(clk) then
      if cfg_mode /= C_MODE_ON then
        state       <= IDLE;
        delay_count <= (others => '0');
      else
        case state is
          when IDLE =>
            if clk_en = '1' then
              if delay_count = 0 then
                state <= START;
              else
                delay_count <= delay_count - 1;
              end if;
            end if;
          when START =>
            if clk_en = '1' then
              state       <= DATA;
              bit_counter := 0;
            end if;
          when DATA =>
            if clk_en = '1' then
              if bit_counter < C_UART_DATA_WIDTH-1 then
                bit_counter := bit_counter + 1;
              else
                state <= STOP;
              end if;
            end if;
          when STOP =>
            if clk_en = '1' then
              if unsigned(DELAY_I) = 0 then
                state <= START;
              else
                state       <= IDLE;
                delay_count <= unsigned(DELAY_I) - 1;
              end if;
            end if;            
          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

  -- datapath: shift register, output bit, start_flag/stop_flag pulses
  process(clk, rst)
  begin
    if rst = '1' then
      shift_reg <= (others => '0');
      tx        <= '1';
      start_flag     <= '0';
      stop_flag      <= '0';
    elsif rising_edge(clk) then
      start_flag <= '0';
      stop_flag  <= '0';

      if cfg_mode /= C_MODE_ON then
        tx <= '1';
      else
        case state is
          when IDLE =>
            tx <= '1';
          when START =>
            tx <= '0';
            if clk_en = '1' then
              shift_reg <= PAYLOAD_I;
              start_flag     <= '1';
            end if;
          when DATA =>
            tx <= shift_reg(0);
            if clk_en = '1' then
              shift_reg <= '0' & shift_reg(C_UART_DATA_WIDTH-1 downto 1);
            end if;
          when STOP =>
            tx <= '1';
            if clk_en = '1' then
              stop_flag <= '1';
            end if;
        end case;
      end if;
    end if;
  end process;

  status <= (
    0      => start_flag,
    1      => stop_flag,
    8      => tx,
    others => '0'
  );

  -- register status to output
  process(rst, clk)
  begin
    if (rst = '1') then
      STATUS_O <= (others => '0');
    elsif rising_edge(clk) then
      STATUS_O <= status;
    end if;
  end process;

end;

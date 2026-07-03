library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- tx_chan:  single UART TX channel
--

entity tx_chan is
  port (
    -- clock and active-high reset
    CLK_I          : in  std_logic;
    RST_I          : in  std_logic;
    -- sync the start of each baud period:
    BAUD_I         : in  std_logic;
    CONFIG_I       : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    STATUS_O       : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DATA_I         : in  std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
    VALID_I        : in  std_logic;
    READY_O        : out std_logic;
    TX_O           : out std_logic;
    DEBUG_O        : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
  );
end;

architecture behavioral of tx_chan is
  signal clk : std_logic;
  signal rst : std_logic;

  -- config fields:
  alias cfg_phase : std_logic_vector(7 downto 0) is CONFIG_I(7 downto 0);
  alias cfg_delay : std_logic_vector(15 downto 0) is CONFIG_I(31 downto 16);

  -- baud phase counter and sample enable
  signal clk_en     : std_logic;

  -- FSM
  type tx_state_t is (IDLE, SHIFT, STOP, DELAY);
  signal state      : tx_state_t;

  -- shift register and bit/rest counters
  signal shift_reg  : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);

  -- status
  signal status     : std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
  signal state_bits : std_logic_vector(1 downto 0);

  -- status flags
  signal start      : std_logic;
  signal ready      : std_logic;

  -- the TX output as readable signal"
  signal tx         : std_logic := '1';

begin
  clk <= CLK_I;
  rst <= RST_I;

  READY_O <= ready;
  TX_O    <= tx;

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


  -- FSM process
  process(clk, rst)
    variable count : unsigned(15 downto 0);
  begin
    if rst='1' then
      state <= IDLE;
      count := (others => '0');
    elsif rising_edge(clk) then
      case state is
        when IDLE =>
          if clk_en = '1' and VALID_I = '1' then
            state <= SHIFT;
            count := (others => '0');
          end if;

        when SHIFT =>
          if clk_en = '1' then
            if count < C_UART_DATA_WIDTH-1 then
              count := count + 1;
            else
              state <= STOP;
            end if;
          end if;

        when STOP =>
          if clk_en = '1' then
            if unsigned(cfg_delay) = 0 then
              state <= IDLE;
            else
              state <= DELAY;
              count := (others => '0');
            end if;
          end if;

        when DELAY =>
          if clk_en = '1' then
            if count < unsigned(cfg_delay) then
              count := count + 1;
            else
              state <= IDLE;
            end if;
          end if;

        when others =>
          state <= IDLE;
      end case;
    end if;
  end process;

    --outputs:
  process(clk, rst)
  begin
    if rst = '1' then
      shift_reg <= (others => '0');
      tx        <= '1';
      ready     <= '0';
      start     <= '0';

    elsif rising_edge(clk) then
      -- one-cycle pulses (default to 0):
      ready <= '0';
      start <= '0';

      case state is
        when IDLE =>
          if clk_en = '1' and VALID_I = '1' then
            shift_reg <= DATA_I;
            tx        <= '0';   -- start bit
            ready     <= '1';
            start     <= '1';   -- start flag (monitoring)
          end if;

        when SHIFT =>
          if clk_en = '1' then
            tx        <= shift_reg(0);
            shift_reg <= '0' & shift_reg(C_UART_DATA_WIDTH-1 downto 1);
          end if;

        when STOP | DELAY =>
          if clk_en = '1' then
            tx <= '1';
          end if;

        when others => null;
      end case;
    end if;
  end process;


  state_bits <= "00" when state = IDLE  else
                "01" when state = SHIFT else
                "10" when state = STOP  else
                "11";  -- DELAY

  status <= (
    0      => start,
    1      => tx,
    2      => VALID_I,
    3      => ready,
    4      => state_bits(0),
    5      => state_bits(1),
    6      => clk_en,
    others => '0'
    );

  process(clk, rst)
  begin
    if rst = '1' then
      STATUS_O <= (others => '0');
    elsif rising_edge(clk) then
      STATUS_O <= status;
    end if;
  end process;

  DEBUG_O <= status;


end;



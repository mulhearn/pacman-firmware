library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- rx_chan:  single UART RX channel
--

entity rx_chan is
  port (
    -- clock and active-high reset
    CLK_I          : in std_logic;
    RST_I          : in std_logic;
    -- sync the start of each baud period:
    BAUD_SYNC_I    : in std_logic;
    CONFIG_I       : in  std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    STATUS_O       : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);
    DATA_O         : out  std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);
    TIMESTAMP_O    : out  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    VALID_O        : out  std_logic;
    READY_I        : in std_logic;
    RX_I           : in std_logic;
    LOOPBACK_I     : in std_logic;
    PATTERN_I      : in std_logic;
    EMUL_I         : in std_logic;
    TIMESTAMP_I    : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    DEBUG_O        : out std_logic_vector(C_RB_DATA_WIDTH-1 downto 0)
  );
end;

architecture behavioral of rx_chan is
  signal clk : std_logic;
  signal rst : std_logic;

  signal rx_comb : std_logic;  -- mux: RX_I or LOOPBACK_I
  signal rx      : std_logic;  -- registered rx_comb, synchronous to CLK_I

  -- config fields
  alias cfg_input    : std_logic_vector(3 downto 0)  is CONFIG_I(7 downto 4);
  alias cfg_phase    : std_logic_vector(3 downto 0)  is CONFIG_I(3 downto 0);

  -- baud phase counter and sample enable
  signal clk_en     : std_logic;  -- pulses when phase_cnt = config_phase

  -- FSM
  type rx_state_t is (IDLE, FIRST, DATA, STOP);
  signal state      : rx_state_t;

  -- shift register for incoming bits and count
  signal shift_reg  : std_logic_vector(C_UART_DATA_WIDTH-1 downto 0);

  -- status register
  signal status     :std_logic_vector(C_RB_DATA_WIDTH-1 downto 0);

  -- status flags:
  signal valid      : std_logic := '0';  --AXI valid
  signal lost       : std_logic;
  signal frame_err  : std_logic;

  signal busy       : std_logic;
  signal start      : std_logic;
  signal update     : std_logic;

begin
  clk <= CLK_I;
  rst <= RST_I;
  VALID_O <= valid;

  -- generate clk_en by counting from BAUD_SYNC_I to cfg_phase
  process(clk, rst)
    variable count : unsigned(3 downto 0);
  begin
    if (rst='1') then
      count := (others => '0');
      clk_en    <= '0';
    elsif rising_edge(clk) then
      if BAUD_SYNC_I = '1' then
        count := (others => '0');
      else
        count := count + 1;
      end if;

      if count = unsigned(cfg_phase) then
        clk_en    <= '1';
      else
        clk_en    <= '0';
      end if;
    end if;
  end process;

  -- input mux: selects rx source
  with cfg_input select rx_comb <=
    '1'        when "0000",
    RX_I       when "0001",
    LOOPBACK_I when "0010",
    PATTERN_I  when "0100",
    EMUL_I     when "1000",
    '1'        when others;

  process(clk, rst)
  begin
    if rst='1' then
      rx <= '1';
    elsif rising_edge(clk) then
      rx <= rx_comb;
    end if;
  end process;

  -- state determination
  process(clk,rst)
    variable bit_counter : integer range 0 to C_UART_DATA_WIDTH-1;
  begin
    if rst='1' then
      state   <= IDLE;
      bit_counter := 0;
    elsif rising_edge(clk) then
      case state is
        when IDLE =>
          if clk_en = '1' and rx = '0' then
            state   <= FIRST;
            bit_counter := 0;
          end if;
        when FIRST =>
          if clk_en = '1' then
            state   <= DATA;
            bit_counter := 1;
          end if;
        when DATA =>
          if clk_en = '1' then
            if bit_counter < C_UART_DATA_WIDTH-1 then
              bit_counter := bit_counter + 1;
            else
              state   <= STOP;
            end if;
          end if;
        when STOP =>
          if clk_en = '1' then
            state <= IDLE;
          end if;
        when others =>
          state <= IDLE;
      end case;
    end if;
  end process;

  process(clk,rst)
  begin
    if rst = '1' then
      shift_reg   <= (others => '0');
      DATA_O      <= (others => '0');
      TIMESTAMP_O <= (others => '0');
      valid       <= '0';
      start <= '0';
      update <= '0';
      frame_err <= '0';
      lost        <= '0';
    elsif rising_edge(clk) then
      start <= '0';
      update <= '0';
      frame_err <= '0';
      lost <= '0';

      -- clear valid when accepted
      if valid = '1' and READY_I = '1' then
        valid <= '0';
      end if;

      case state is
        when IDLE => null;
        when FIRST | DATA =>
          if clk_en = '1' then
            shift_reg <= rx & shift_reg(C_UART_DATA_WIDTH-1 downto 1);
            if (state = FIRST) then
              start <= '1';
            end if;
          end if;
        when STOP =>
          if clk_en = '1' then
            if rx = '1' then
              update <= '1';
              if valid = '1' and READY_I = '0' then
                lost <= '1';            -- overrun: previous byte not yet taken
              else
                DATA_O      <= shift_reg;
                TIMESTAMP_O <= TIMESTAMP_I;
                valid     <= '1';
              end if;
            else
              frame_err <= '1';
            end if;
          end if;
      end case;
    end if;
  end process;

  busy <= '1' when state /= IDLE else '0';

  status <= (
    0      => clk_en,
    1      => busy,
    2      => valid,
    3      => READY_I,
    4      => start,
    5      => update,
    6      => lost,
    7      => frame_err,
    8      => rx,
    9      => '0',
    12     => RX_I,
    13     => LOOPBACK_I,
    14     => PATTERN_I,
    15     => EMUL_I,
    others => '0'
  );

  DEBUG_O <= status;

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

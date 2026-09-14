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
    BAUD_I         : in std_logic;
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

  signal rx_comb : std_logic;  -- mux: RX_I / LOOPBACK_I / PATTERN_I / EMUL_I
  signal rx_meta : std_logic;  -- first sync stage: metastability risk
  signal rx_sync : std_logic;  -- second sync stage: should be stable
  -- pipeline rx_sync history for edge detection and majority voting
  signal rx_taps : std_logic_vector(2 downto 0);

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of rx_meta : signal is "TRUE";
  attribute ASYNC_REG of rx_sync : signal is "TRUE";

  signal rx_vote    : std_logic;  -- majority vote rx sample
  signal rx_dissent : std_logic;  -- high if majority vote was non-unanimous
  signal rx_fall    : std_logic;  -- falling edge in rx sample with glitch removal

  -- config fields
  alias cfg_period : std_logic_vector(7 downto 0)  is CONFIG_I(23 downto 16);
  alias cfg_flags  : std_logic_vector(1 downto 0)  is CONFIG_I(15 downto 14);
  alias cfg_mode   : std_logic_vector(1 downto 0)  is CONFIG_I(13 downto 12);
  alias cfg_input  : std_logic_vector(3 downto 0)  is CONFIG_I(11 downto 8);
  alias cfg_phase  : std_logic_vector(7 downto 0)  is CONFIG_I(7 downto 0);

  -- count since last baud sync
  signal rx_phase  : std_logic_vector(7 downto 0);
  signal sample_en : std_logic;

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
  signal noise      : std_logic;  -- majority vote non-unanimous and sample enable

  signal start      : std_logic;
  signal update     : std_logic;

begin
  clk <= CLK_I;
  rst <= RST_I;
  VALID_O <= valid;

  -- input mux: selects rx source
  with cfg_input select rx_comb <=
    '1'        when "0000",
    RX_I       when "0001",
    LOOPBACK_I when "0010",
    PATTERN_I  when "0100",
    EMUL_I     when "1000",
    '1'        when others;

  -- double flop synchronization of RX input (with unknown cable delay phase)
  process(clk, rst)
  begin
    if rst='1' then
      rx_meta <= '1';
      rx_sync <= '1';
    elsif rising_edge(clk) then
      rx_meta <= rx_comb;
      rx_sync <= rx_meta;
    end if;
  end process;

  -- pipeline RX input:
  rx_taps(0) <= rx_sync;  -- alias rx_taps(0) to rx_sync for convenient notation:
  process(clk, rst)
  begin
    if (rst='1') then
      rx_taps(2 downto 1) <= (others => '1');
    elsif rising_edge(clk) then
      rx_taps(2 downto 1) <= rx_taps(1 downto 0);
    end if;
  end process;

  -- edge detection and majority voting:
  rx_vote <= '1' when (rx_taps(0) = '1' and rx_taps(1) = '1') or
             (rx_taps(1) = '1' and rx_taps(2) = '1') or
             (rx_taps(2) = '1' and rx_taps(0) = '1')
           else '0';

  rx_dissent <= '1' when (rx_taps(0) /= rx_taps(1)) or (rx_taps(1) /= rx_taps(2)) else '0';

  noise <= '1' when rx_dissent='1' and sample_en='1' else '0';

  rx_fall <= '1' when (rx_taps(0) = '0' and rx_taps(1) = '0' and rx_taps(2) = '1') else '0';

  -- start-bit phase detection, and configurable sample enable:
  process(clk, rst)
    variable baud_count    : unsigned(7 downto 0);
    variable edge_detected : std_logic;
    -- configurable sample point phase, by default relative to detected falling
    -- edge (rx_phase):
    variable sample_phase  : unsigned(7 downto 0);
  begin
    if (rst='1') then
      baud_count := (others => '0');
      edge_detected := '0';
      sample_phase  := (others => '1');
      rx_phase  <= (others => '1');
      sample_en <= '0';
    elsif rising_edge(clk) then

      if (edge_detected='0') and (state = IDLE) and (rx_fall='1') then
        rx_phase <= std_logic_vector(baud_count);
        edge_detected := '1';
        if cfg_mode = "01" then
          sample_phase := baud_count + unsigned(cfg_phase);
          -- wrap up to one period: (sufficient for cfg_phase < cfg_period)
          if (sample_phase >= unsigned(cfg_period)) then
            sample_phase := sample_phase - unsigned(cfg_period);
          end if;
        end if;

      elsif (edge_detected='1') and (rx_vote='1') and (rx_dissent='0') then
        edge_detected := '0';
      end if;

      if cfg_mode = "00" then -- disabled:
        sample_phase  := (others => '1');
      elsif cfg_mode = "01" then -- handled above
        null;
      elsif cfg_mode = "10" then -- fixed phase mode
        sample_phase := unsigned(cfg_phase);
      else
        sample_phase  := (others => '1'); --reserved
      end if;

      if baud_count = sample_phase then
        sample_en <= '1';
      else
        sample_en <= '0';
      end if;


      if BAUD_I = '1' then
        baud_count := (others => '0');
      else
        baud_count := baud_count + 1;
      end if;

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
         if (sample_en = '1') and (rx_vote = '0') and ((rx_dissent = '0') or (cfg_flags(0) = '1')) then
            state   <= FIRST;
            bit_counter := 0;
          end if;
        when FIRST =>
          if sample_en = '1' then
            state   <= DATA;
            bit_counter := 1;
          end if;
        when DATA =>
          if sample_en = '1' then
            if bit_counter < C_UART_DATA_WIDTH-1 then
              bit_counter := bit_counter + 1;
            else
              state   <= STOP;
            end if;
          end if;
        when STOP =>
          if sample_en = '1' then
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
          if sample_en = '1' then
            shift_reg <= rx_vote & shift_reg(C_UART_DATA_WIDTH-1 downto 1);
            if (state = FIRST) then
              start <= '1';
            end if;
          end if;
        when STOP =>
          if sample_en = '1' then
            if rx_vote = '1' then
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

  status(1 downto 0) <= std_logic_vector(to_unsigned(rx_state_t'pos(state), 2));

  status(23 downto 2) <= (
    2      => valid,
    3      => READY_I,

    4      => start,
    5      => update,
    6      => lost,
    7      => frame_err,

    8      => noise,
    9      => BAUD_I,
    10     => sample_en,
    11     => rx_dissent,

    12     => rx_taps(0),
    13     => rx_taps(1),
    14     => rx_taps(2),
    15     => rx_vote,

    16     => RX_I,
    17     => LOOPBACK_I,
    18     => PATTERN_I,
    19     => EMUL_I,

    others => '0'
  );
  status(31 downto 24) <= rx_phase;

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

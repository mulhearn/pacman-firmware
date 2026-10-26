library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;

-- bram_buffer: a capture into a circular BRAM buffer, its trigger, and readout.
--
-- A sample (SAMPLE_I, C_WIDTH bits) is written on each sample strobe (SE_I) while acquisition is
-- enabled (ENABLE_I).  ARM starts a capture.  The trigger is an edge (rising, falling, either) of
-- one sample bit, FORCE, or TRIG_I (when TRIG_EN_I);  it is evaluated every clock, so a one-clock
-- FORCE or TRIG_I is never missed.  The triggering sample is the next one stored (the edge's own
-- sample, which is written in the clock of the edge).  POST more samples are written after the
-- triggering one (at most depth-1), then the capture is done.  One trigger per ARM.  TRIG_O pulses
-- for one clock when the capture triggers.
--
-- Trigger timestamp:  TS_I in the clock of the trigger;  for TRIG_I alone, TS_I of the clock before
-- (TRIG_I is another buffer's TRIG_O, one clock late), so both buffers keep the same timestamp.
--
-- Edges:  between the sample of a strobe and the sample of the strobe before (not the first strobe
-- after ARM);  a trigger bit >= C_WIDTH never triggers.
--
-- Acquisition disabled (ENABLE_I low):  nothing is written (pointer and COUNT hold);  arm, the
-- trigger, its timestamp, TRIG_O, POST (counted in strobes) and DONE run as usual:  a trigger
-- router, with its timestamp.
--
-- Readout in time order:  START points at the oldest sample, NEXT advances, DATA is the sample
-- pointed at (bits above C_WIDTH zero).

entity bram_buffer is
  generic (
    C_DEPTH_LOG2   : integer := 15;     -- 32K samples
    C_WIDTH        : integer := 32      -- sample bits (at most 32)
  );
  port (
    CLK_I          : in  std_logic;
    RST_I          : in  std_logic;

    -- sample, its strobe and timestamp
    SAMPLE_I       : in  std_logic_vector(C_WIDTH-1 downto 0);
    SE_I           : in  std_logic;
    TS_I           : in  std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);

    -- configuration (registers)
    ENABLE_I       : in  std_logic;                           -- acquisition enable
    TRIG_BIT_I     : in  std_logic_vector(4 downto 0);
    TRIG_EDGE_I    : in  std_logic_vector(1 downto 0);        -- 0 rising, 1 falling, 2 or 3 either
    TRIG_EN_I      : in  std_logic;                           -- 1:  TRIG_I triggers
    POST_I         : in  std_logic_vector(31 downto 0);

    -- commands (one-clock strobes)
    ARM_I          : in  std_logic;
    FORCE_I        : in  std_logic;
    START_I        : in  std_logic;
    NEXT_I         : in  std_logic;

    -- cross trigger
    TRIG_I         : in  std_logic;
    TRIG_O         : out std_logic;

    -- status and readout
    ARMED_O        : out std_logic;
    TRIGGERED_O    : out std_logic;
    DONE_O         : out std_logic;
    TRIG_POS_O     : out std_logic_vector(31 downto 0);
    COUNT_O        : out std_logic_vector(31 downto 0);
    TRIG_TS_O      : out std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0);
    DATA_O         : out std_logic_vector(31 downto 0)
  );
end bram_buffer;

architecture rtl of bram_buffer is
  constant C_DEPTH  : integer := 2**C_DEPTH_LOG2;

  subtype addr_t is unsigned(C_DEPTH_LOG2-1 downto 0);

  type state_t is (S_IDLE, S_ARMED, S_TRIGGERED, S_DONE);
  signal state     : state_t := S_IDLE;
  signal prev_r    : std_logic_vector(C_WIDTH-1 downto 0) := (others => '0');
  signal wptr      : addr_t := (others => '0');
  signal total     : unsigned(C_DEPTH_LOG2 downto 0) := (others => '0');   -- samples written, saturates at C_DEPTH
  signal have_prev : std_logic := '0';
  signal remaining : unsigned(31 downto 0) := (others => '0');            -- samples still to take
  signal trig_addr : addr_t := (others => '0');
  signal ts_d      : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0) := (others => '0');
  signal trig_ts   : std_logic_vector(C_TIMESTAMP_WIDTH-1 downto 0) := (others => '0');
  signal trig_r    : std_logic := '0';
  signal oldest    : addr_t;
  signal rptr      : addr_t := (others => '0');
  signal rptr_n    : addr_t;

  type ram_t is array (0 to C_DEPTH-1) of std_logic_vector(C_WIDTH-1 downto 0);
  signal ram  : ram_t;
  signal cap  : std_logic;               -- a sample of the capture (written if acquisition enabled)
  signal we   : std_logic;
  signal q    : std_logic_vector(C_WIDTH-1 downto 0) := (others => '0');
begin

  assert C_WIDTH >= 1 and C_WIDTH <= 32
                                     report "bram_buffer:  C_WIDTH must be 1 to 32" severity failure;

  -- capture
  cap <= SE_I when (state = S_ARMED) or (state = S_TRIGGERED and remaining /= 0) else '0';
  we  <= cap and ENABLE_I;

  process(CLK_I, RST_I)
    variable b : integer;
    variable bit_now, bit_prev : std_logic;
    variable edge, cross, fire : boolean;
    variable post_c : unsigned(31 downto 0);
  begin
    if (RST_I = '1') then
      state     <= S_IDLE;
      wptr      <= (others => '0');
      total     <= (others => '0');
      have_prev <= '0';
      prev_r    <= (others => '0');
      remaining <= (others => '0');
      trig_addr <= (others => '0');
      ts_d      <= (others => '0');
      trig_ts   <= (others => '0');
      trig_r    <= '0';
    elsif rising_edge(CLK_I) then
      ts_d   <= TS_I;
      trig_r <= '0';
      if ARM_I = '1' then
        state     <= S_ARMED;
        wptr      <= (others => '0');
        total     <= (others => '0');
        have_prev <= '0';
        remaining <= (others => '0');
      else
        if we = '1' then
          wptr <= wptr + 1;
          if total /= C_DEPTH then
            total <= total + 1;
          end if;
        end if;
        if SE_I = '1' then
          prev_r    <= SAMPLE_I;
          have_prev <= '1';
        end if;
        if state = S_ARMED then
          b := to_integer(unsigned(TRIG_BIT_I));
          edge := false;
          if SE_I = '1' and have_prev = '1' and b < C_WIDTH then
            bit_now  := SAMPLE_I(b);
            bit_prev := prev_r(b);
            edge := bit_now /= bit_prev and
                    ((TRIG_EDGE_I = "00" and bit_now = '1') or (TRIG_EDGE_I = "01" and bit_now = '0') or
                     TRIG_EDGE_I(1) = '1');
          end if;
          cross := TRIG_EN_I = '1' and TRIG_I = '1';
          fire  := edge or FORCE_I = '1' or cross;
          if fire then
            trig_r    <= '1';
            trig_addr <= wptr;
            if edge or FORCE_I = '1' then
              trig_ts <= TS_I;
            else
              trig_ts <= ts_d;
            end if;
            if unsigned(POST_I) > C_DEPTH-1 then
              post_c := to_unsigned(C_DEPTH-1, 32);
            else
              post_c := unsigned(POST_I);
            end if;
            if SE_I = '1' then
              -- the triggering sample is taken in this clock
              remaining <= post_c;
              if post_c = 0 then
                state <= S_DONE;
              else
                state <= S_TRIGGERED;
              end if;
            else
              -- the triggering sample is the next one
              remaining <= post_c + 1;
              state     <= S_TRIGGERED;
            end if;
          end if;
        elsif state = S_TRIGGERED and cap = '1' then
          remaining <= remaining - 1;
          if remaining = 1 then
            state <= S_DONE;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- read pointer:  the BRAM reads the new pointer in the clock of the command, so DATA is valid one clock later
  oldest <= (others => '0') when total /= C_DEPTH else wptr;
  rptr_n <= oldest when START_I = '1' else rptr + 1 when NEXT_I = '1' else rptr;

  process(CLK_I, RST_I)
  begin
    if (RST_I = '1') then
      rptr <= (others => '0');
    elsif rising_edge(CLK_I) then
      rptr <= rptr_n;
    end if;
  end process;

  -- BRAM (no reset:  inferred block RAM)
  process(CLK_I)
  begin
    if rising_edge(CLK_I) then
      if we = '1' then
        ram(to_integer(wptr)) <= SAMPLE_I;
      end if;
      q <= ram(to_integer(rptr_n));
    end if;
  end process;

  TRIG_O      <= trig_r;
  ARMED_O     <= '1' when state = S_ARMED else '0';
  TRIGGERED_O <= '1' when state = S_TRIGGERED else '0';
  DONE_O      <= '1' when state = S_DONE else '0';
  TRIG_POS_O  <= std_logic_vector(resize(trig_addr - oldest, 32));
  COUNT_O     <= std_logic_vector(resize(total, 32));
  TRIG_TS_O   <= trig_ts;
  DATA_O      <= std_logic_vector(resize(unsigned(q), 32));

end rtl;

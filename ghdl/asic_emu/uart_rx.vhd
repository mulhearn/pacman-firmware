library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- uart_rx (VHDL replacement for uart_rx.sv)

entity uart_rx is
  generic (
    WIDTH : integer := 64
  );
  port (
    rx_data     : out std_logic_vector(WIDTH-1 downto 0);
    rx_empty    : out std_logic;
    rx_in       : in  std_logic;
    uld_rx_data : in  std_logic;
    clk         : in  std_logic;
    reset_n     : in  std_logic
  );
end entity uart_rx;

architecture behaviour of uart_rx is

  -- Width of bit counter: enough bits to count 0 to WIDTH-1
  -- ceil(log2(WIDTH)) for WIDTH=64 is 6 bits
  function clog2(n : integer) return integer is
    variable r : integer := 0;
    variable v : integer := n - 1;
  begin
    while v > 0 loop
      r := r + 1;
      v := v / 2;
    end loop;
    return r;
  end function;

  constant CNT_W : integer := clog2(WIDTH);

  -- Two-flop synchronizer (initialize to idle = '1')
  signal sync_0  : std_logic := '1';
  signal rx_sync : std_logic := '1';

  -- Reception state (initialize so pre-reset simulation is well-defined)
  signal busy        : std_logic := '0';
  signal bit_cnt     : unsigned(CNT_W-1 downto 0) := (others => '0');
  signal shift_reg   : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
  signal hold_reg    : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
  signal hold_valid  : std_logic := '0';
  signal rx_data_r   : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
  signal rx_empty_r  : std_logic := '1';

  -- Combinatorial next-state signals
  signal busy_next      : std_logic := '0';
  signal bit_cnt_next   : unsigned(CNT_W-1 downto 0) := (others => '0');
  signal shift_reg_next : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
  signal packet_ready   : std_logic := '0';

begin

  -- Two-flop synchronizer
  sync_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      sync_0  <= '1';
      rx_sync <= '1';
    elsif rising_edge(clk) then
      sync_0  <= rx_in;
      rx_sync <= sync_0;
    end if;
  end process;

  -- Combinatorial next-state logic
  nxt_proc : process(busy, bit_cnt, shift_reg, rx_sync)
  begin
    -- defaults: hold current values
    busy_next      <= busy;
    bit_cnt_next   <= bit_cnt;
    shift_reg_next <= shift_reg;
    packet_ready   <= '0';

    if busy = '0' then
      -- IDLE: wait for start bit (line goes low)
      if rx_sync = '0' then
        busy_next      <= '1';
        bit_cnt_next   <= (others => '0');
        shift_reg_next <= (others => '0');
      end if;
    else
      -- RECEIVING: capture one data bit each clock (LSB-first)
      shift_reg_next(to_integer(bit_cnt)) <= rx_sync;

      if bit_cnt = to_unsigned(WIDTH-1, CNT_W) then
        -- All data bits captured
        packet_ready <= '1';
        busy_next    <= '0';
      else
        bit_cnt_next <= bit_cnt + 1;
      end if;
    end if;
  end process;

  -- Reception registers + double-buffer handling
  rx_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      busy       <= '0';
      bit_cnt    <= (others => '0');
      shift_reg  <= (others => '0');
      hold_reg   <= (others => '0');
      hold_valid <= '0';
      rx_data_r  <= (others => '0');
      rx_empty_r <= '1';
    elsif rising_edge(clk) then

      -- Host read request (uld_rx_data pulse)
      if uld_rx_data = '1' then
        if hold_valid = '1' then
          rx_data_r  <= hold_reg;
          hold_valid <= '0';
          rx_empty_r <= '0';
        else
          rx_empty_r <= '1';
        end if;
      end if;

      -- Reception registers
      busy      <= busy_next;
      bit_cnt   <= bit_cnt_next;
      shift_reg <= shift_reg_next;

      -- Word completed: double-buffer handling
      if packet_ready = '1' then
        if rx_empty_r = '1' then
          -- Primary buffer free: deliver immediately
          rx_data_r  <= shift_reg_next;
          rx_empty_r <= '0';
        else
          -- Primary buffer occupied: store in hold register
          hold_reg   <= shift_reg_next;
          hold_valid <= '1';
        end if;
      end if;

    end if;
  end process;

  rx_data  <= rx_data_r;
  rx_empty <= rx_empty_r;

end architecture behaviour;

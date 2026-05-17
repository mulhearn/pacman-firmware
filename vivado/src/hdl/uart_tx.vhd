library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- uart_tx (VHDL replacement for uart_tx.sv)

entity uart_tx is
  generic (
    WIDTH : integer := 64
  );
  port (
    tx_out     : out std_logic;
    tx_busy    : out std_logic;
    tx_data    : in  std_logic_vector(WIDTH-1 downto 0);
    ld_tx_data : in  std_logic;
    tx_enable  : in  std_logic;
    clk        : in  std_logic;
    reset_n    : in  std_logic
  );
end entity uart_tx;

architecture behaviour of uart_tx is
  signal tx_reg  : std_logic_vector(WIDTH-1 downto 0);
  signal tx_cnt  : unsigned(7 downto 0);
  signal tx_bit  : std_logic;
  signal tx_busy_r : std_logic;
begin

  -- Main TX state machine (posedge clk, async active-low reset)
  process(clk, reset_n)
  begin
    if reset_n = '0' then
      tx_reg    <= (others => '0');
      tx_busy_r <= '0';
      tx_bit    <= '1';
      tx_cnt    <= (others => '0');
    elsif rising_edge(clk) then
      if tx_enable = '1' then
        if ld_tx_data = '1' then
          tx_reg    <= tx_data;
          tx_busy_r <= '1';
        end if;
        if tx_busy_r = '1' then
          tx_cnt <= tx_cnt + 1;
          if tx_cnt = 0 then
            tx_bit <= '0';  -- start bit
          end if;
          if tx_cnt > 0 and tx_cnt <= WIDTH then
            tx_bit <= tx_reg(to_integer(tx_cnt) - 1);
          end if;
          if tx_cnt > WIDTH then
            tx_bit    <= '1';   -- stop bit / idle
            tx_cnt    <= (others => '0');
            tx_busy_r <= '0';
          end if;
        end if;
      end if;
      -- when tx_enable = '0', flops simply hold (no assignment)
    end if;
  end process;

  tx_busy <= tx_busy_r;

  -- Output launches on negedge of clk for settling margin
  process(clk, reset_n)
  begin
    if reset_n = '0' then
      tx_out <= '1';
    elsif falling_edge(clk) then
      tx_out <= tx_bit;
    end if;
  end process;

end architecture behaviour;

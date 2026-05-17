library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
library work;
use work.common.all;

-- asic_emu_unit: ASIC emulation unit
--
-- Implements the LArPix digital_core on FPGA.
--
entity asic_emu_unit is
  port (
    UCLK_I  : in  std_logic;
    G_I     : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    H_I     : in  std_logic_vector(C_NUM_TILE-1 downto 0);
    POSI_I  : in  std_logic_vector(C_NUM_UART-1 downto 0);
    PISO_O  : out std_logic_vector(C_NUM_UART-1 downto 0)
  );
end asic_emu_unit;

architecture behaviour of asic_emu_unit is
  
  component uart_rx is
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
  end component;
  
  component uart_tx is
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
  end component;

  signal clk        : std_logic;
  signal reset_n    : std_logic;

  signal tx_out     : std_logic;
  signal tx_busy    : std_logic;
  signal tx_data    : std_logic_vector(63 downto 0) := x"33335555FFFF3333";
  signal ld_tx_data : std_logic := '0';
  signal tx_enable  : std_logic := '1';

  signal rx_in       : std_logic := '1';  -- idle high
  signal uld_rx_data : std_logic := '0';
  signal rx_data     : std_logic_vector(63 downto 0);
  signal rx_empty    : std_logic;

begin
  clk <= UCLK_I;
  reset_n <= G_I(0);
  PISO_O  <= (others => tx_out);
  rx_in <= POSI_I(0);

  --loopback RX to TX
  ld_tx_data  <= '1' when rx_empty = '0' and tx_busy = '0' else '0';
  uld_rx_data <= '1' when rx_empty = '0' and tx_busy = '0' else '0';
  tx_data     <= rx_data;
  
  urx0: uart_rx port map (
    rx_data     => rx_data,
    rx_empty    => rx_empty,
    rx_in       => rx_in,
    uld_rx_data => uld_rx_data,
    clk         => clk,
    reset_n     => reset_n
  );

  utx0: uart_tx port map (
    tx_out     => tx_out,
    tx_busy    => tx_busy,
    tx_data    => tx_data,
    ld_tx_data => ld_tx_data,
    tx_enable  => tx_enable,
    clk        => clk,
    reset_n    => reset_n
  );

end behaviour;

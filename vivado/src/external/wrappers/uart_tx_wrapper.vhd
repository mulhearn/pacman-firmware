---------------------------------------------------------------------
-- File:        uart_tx_wrapper.vhd
-- Description: VHDL wrapper around the LArPix uart_tx SystemVerilog
--              module, allowing it to be instantiated in VHDL contexts
--              and added to Vivado Block Designs.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity uart_tx_wrapper is
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        tx_enable   : in  std_logic;
        ld_tx_data  : in  std_logic;
        tx_data     : in  std_logic_vector(63 downto 0);
        tx_out      : out std_logic;
        tx_busy     : out std_logic
    );
end entity uart_tx_wrapper;

architecture rtl of uart_tx_wrapper is

    component uart_tx
        port (
            tx_out     : out std_logic;
            tx_busy    : out std_logic;
            tx_data    : in  std_logic_vector(63 downto 0);
            ld_tx_data : in  std_logic;
            tx_enable  : in  std_logic;
            clk        : in  std_logic;
            reset_n    : in  std_logic
        );
    end component;

begin

    u_uart_tx : uart_tx
        port map (
            tx_out     => tx_out,
            tx_busy    => tx_busy,
            tx_data    => tx_data,
            ld_tx_data => ld_tx_data,
            tx_enable  => tx_enable,
            clk        => clk,
            reset_n    => reset_n
        );

end architecture rtl;

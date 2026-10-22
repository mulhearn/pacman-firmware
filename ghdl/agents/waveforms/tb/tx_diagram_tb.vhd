-- Diagram testbench (make waveforms):  tx_unit sending two DMA packets back to back, for the firmware
-- description (tx_stream.pdf, tx_frames.pdf).  All UARTs configured 00020006 (broadcast write:  phase 6,
-- delay 2 bit periods);  BAUD every 10 clocks.  Packet 1 masks UARTs 0-2, packet 2 UARTs 0 and 1;  the
-- stream offers packet 2 right after packet 1:  it is read at once, moves to the output buffer (valid) and
-- waits there while packet 1 is transmitted;  the stream reader is free again for a third packet.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.common.all;
use work.register_map.all;

entity tx_diagram_tb is
end tx_diagram_tb;

architecture behaviour of tx_diagram_tb is
  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';
  signal baud    : std_logic := '0';
  signal tdata   : std_logic_vector(63 downto 0) := (others => '0');
  signal tvalid  : std_logic := '0';
  signal tready  : std_logic;
  signal tlast   : std_logic := '0';
  signal waddr   : std_logic_vector(15 downto 0) := (others => '0');
  signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal wupdate : std_logic := '0';
  signal posi    : std_logic_vector(C_NUM_UART-1 downto 0);
  signal beat    : integer := 0;     -- beat number within the packet being offered (0 = mask)
begin
  uut: entity work.tx_unit port map (
    ACLK                => clk,
    RST_I               => rst,
    BAUD_I              => baud,
    S_AXIS_TDATA        => tdata,
    S_AXIS_TVALID       => tvalid,
    S_AXIS_TREADY       => tready,
    S_AXIS_TKEEP        => (others => '1'),
    S_AXIS_TLAST        => tlast,
    S_REGBUS_RB_RADDR   => (others => '0'),
    S_REGBUS_RB_RDATA   => open,
    S_REGBUS_RB_RUPDATE => '0',
    S_REGBUS_RB_RACK    => open,
    S_REGBUS_RB_WUPDATE => wupdate,
    S_REGBUS_RB_WADDR   => waddr,
    S_REGBUS_RB_WDATA   => wdata,
    S_REGBUS_RB_WACK    => open,
    POSI_O              => posi,
    DEBUG_O             => open
  );

  clk <= not clk after 5 ns;
  rst <= '0' after 20 ns;

  process
  begin
    wait until rising_edge(clk);
    loop
      for i in 1 to 9 loop wait until rising_edge(clk); end loop;
      baud <= '1';
      wait until rising_edge(clk);
      baud <= '0';
    end loop;
  end process;

  process
    procedure packet(mask : std_logic_vector(39 downto 0); n : integer) is
    begin
      for b in 0 to C_TX_AXIS_BEATS-1 loop
        beat <= b;
        if b = 0 then
          tdata <= x"000000" & mask;
        else      -- UART b-1:  AAAA... (bits alternate on the line), low 16 bits 0x0n0u (packet n, UART u)
          tdata <= x"AAAAAAAAAAAA" & std_logic_vector(to_unsigned(n * 256 + b - 1, 16));
        end if;
        tvalid <= '1';
        if b = C_TX_AXIS_BEATS-1 then tlast <= '1'; else tlast <= '0'; end if;
        loop
          wait until rising_edge(clk);
          exit when tready = '1';
        end loop;
        wait for 1 ns;
      end loop;
      tvalid <= '0';
      tlast <= '0';
      tdata <= (others => '0');
    end procedure;
  begin
    wait for 40 ns;
    wait until rising_edge(clk);
    wait for 1 ns;
    waddr <= std_logic_vector(to_unsigned(C_SCOPE_UPPER_TX * 16#4000# + C_CHAN_BROADCAST * 16#100#
                                          + C_ADDR_TX_UART_CONFIG, 16));
    wdata <= x"00020006";
    wupdate <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    wupdate <= '0';
    wait for 50 ns;
    wait until rising_edge(clk);
    wait for 1 ns;
    packet(x"0000000007", 1);
    packet(x"0000000003", 2);
    wait;
  end process;
end behaviour;

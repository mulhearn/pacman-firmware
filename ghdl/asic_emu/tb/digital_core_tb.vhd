library ieee;
use std.textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use IEEE.std_logic_textio.all;  -- use -fsynopsys or --std=08
library work;
use work.common.all;

entity digital_core_tb is
end digital_core_tb;
architecture behaviour of digital_core_tb is
  component digital_core is
    port (
      piso                    : out std_logic_vector(3 downto 0);
      digital_monitor         : out std_logic;
      sample                  : out std_logic_vector(63 downto 0);
      tx_enable               : out std_logic_vector(3 downto 0);
      pixel_trim_dac          : out std_logic_vector(319 downto 0);
      threshold_global        : out std_logic_vector(7 downto 0);
      gated_reset             : out std_logic_vector(63 downto 0);
      csa_reset               : out std_logic_vector(63 downto 0);
      bypass_caps_enable      : out std_logic_vector(63 downto 0);
      ibias_tdac              : out std_logic_vector(15 downto 0);
      ibias_comp              : out std_logic_vector(15 downto 0);
      ibias_buffer            : out std_logic_vector(15 downto 0);
      ibias_csa               : out std_logic_vector(15 downto 0);
      ibias_vref_buffer       : out std_logic_vector(3 downto 0);
      ibias_vcm_buffer        : out std_logic_vector(3 downto 0);
      ibias_tpulse            : out std_logic_vector(3 downto 0);
      adc_ibias_delay         : out std_logic_vector(15 downto 0);
      ref_current_trim        : out std_logic_vector(4 downto 0);
      adc_comp_trim           : out std_logic_vector(1 downto 0);
      vref_dac                : out std_logic_vector(7 downto 0);
      vcm_dac                 : out std_logic_vector(7 downto 0);
      csa_bypass_enable       : out std_logic_vector(63 downto 0);
      csa_bypass_select       : out std_logic_vector(63 downto 0);
      csa_monitor_select      : out std_logic_vector(63 downto 0);
      csa_testpulse_enable    : out std_logic_vector(63 downto 0);
      csa_testpulse_dac       : out std_logic_vector(7 downto 0);
      adc_ibias_delay_monitor : out std_logic_vector(3 downto 0);
      current_monitor_bank0   : out std_logic_vector(3 downto 0);
      current_monitor_bank1   : out std_logic_vector(3 downto 0);
      current_monitor_bank2   : out std_logic_vector(3 downto 0);
      current_monitor_bank3   : out std_logic_vector(3 downto 0);
      voltage_monitor_bank0   : out std_logic_vector(2 downto 0);
      voltage_monitor_bank1   : out std_logic_vector(2 downto 0);
      voltage_monitor_bank2   : out std_logic_vector(2 downto 0);
      voltage_monitor_bank3   : out std_logic_vector(2 downto 0);
      voltage_monitor_refgen  : out std_logic_vector(7 downto 0);
      en_analog_monitor       : out std_logic;
      tx_slices0              : out std_logic_vector(3 downto 0);
      tx_slices1              : out std_logic_vector(3 downto 0);
      tx_slices2              : out std_logic_vector(3 downto 0);
      tx_slices3              : out std_logic_vector(3 downto 0);
      i_tx_diff0              : out std_logic_vector(3 downto 0);
      i_tx_diff1              : out std_logic_vector(3 downto 0);
      i_tx_diff2              : out std_logic_vector(3 downto 0);
      i_tx_diff3              : out std_logic_vector(3 downto 0);
      i_rx0                   : out std_logic_vector(3 downto 0);
      i_rx1                   : out std_logic_vector(3 downto 0);
      i_rx2                   : out std_logic_vector(3 downto 0);
      i_rx3                   : out std_logic_vector(3 downto 0);
      i_rx_clk                : out std_logic_vector(3 downto 0);
      i_rx_rst                : out std_logic_vector(3 downto 0);
      i_rx_ext_trig           : out std_logic_vector(3 downto 0);
      r_term0                 : out std_logic_vector(4 downto 0);
      r_term1                 : out std_logic_vector(4 downto 0);
      r_term2                 : out std_logic_vector(4 downto 0);
      r_term3                 : out std_logic_vector(4 downto 0);
      r_term_clk              : out std_logic_vector(4 downto 0);
      r_term_rst              : out std_logic_vector(4 downto 0);
      r_term_ext_trig         : out std_logic_vector(4 downto 0);
      v_cm_lvds_tx0           : out std_logic_vector(3 downto 0);
      v_cm_lvds_tx1           : out std_logic_vector(3 downto 0);
      v_cm_lvds_tx2           : out std_logic_vector(3 downto 0);
      v_cm_lvds_tx3           : out std_logic_vector(3 downto 0);
      dout                    : in  std_logic_vector(639 downto 0);
      done                    : in  std_logic_vector(63 downto 0);
      hit                     : in  std_logic_vector(63 downto 0);
      external_trigger        : in  std_logic;
      posi                    : in  std_logic_vector(3 downto 0);
      clk                     : in  std_logic;
      reset_n                 : in  std_logic
      );
  end component;
  signal count   : integer := 0;
  signal clk     : std_logic;
  signal rst_n   : std_logic := '0';
  signal posi    : std_logic_vector(3 downto 0) := (others => '0');
  signal piso    : std_logic_vector(3 downto 0);
  signal tx_en   : std_logic_vector(3 downto 0);
  signal ext_trig : std_logic := '0';
  signal dout_in : std_logic_vector(639 downto 0) := (others => '0');
  signal done_in : std_logic_vector(63 downto 0)  := (others => '0');
  signal hit_in  : std_logic_vector(63 downto 0)  := (others => '0');
  -- output sinks (we don't check these, just need somewhere for them to go)
  signal dig_mon : std_logic;
  signal samp    : std_logic_vector(63 downto 0);
begin
  uut0: digital_core port map (
    clk              => clk,
    reset_n          => rst_n,
    posi             => posi,
    piso             => piso,
    tx_enable        => tx_en,
    external_trigger => ext_trig,
    dout             => dout_in,
    done             => done_in,
    hit              => hit_in,
    digital_monitor  => dig_mon,
    sample           => samp
  );
  reset_process : process
  begin
    rst_n <= '0';
    wait for 20 ns;
    rst_n <= '1';
    wait;
  end process;
  clk_process : process
  begin
    count <= count + 1;
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;
  stimulus_process : process
  begin
    posi <= (others => '0');
    wait for 30 ns;
    -- Walk a 1 across the four UART receive lines
    posi <= "0001";
    wait for 10 ns;
    posi <= "0010";
    wait for 10 ns;
    posi <= "0100";
    wait for 10 ns;
    posi <= "1000";
    wait for 10 ns;
    posi <= "1111";
    wait for 10 ns;
    posi <= (others => '0');
    wait;
  end process;

  output_process : process
    variable l : line;
  begin
    wait for 10 ns;
    write (l, String'("c: "));
    write (l, count, left, 4);
    write (l, String'(" | posi: 0x"));
    hwrite (l, posi);
    write (l, String'(" piso: 0x"));
    hwrite (l, piso);
    write (l, String'(" tx_en: 0x"));
    hwrite (l, tx_en);
    if (rst_n = '0') then
      write (l, String'(" (RESET)"));
    end if;
    writeline(output, l);
  end process;

  comment_process : process
    variable l : line;
  begin
    wait until (count=4);
    write(l, String'("INFO:  Walking 1 across posi; expect piso to mirror:"));
    writeline(output, l);
    wait until (count=8);
    write(l, String'("INFO:  All posi lines high; expect piso = 0xF"));
    writeline(output, l);
    wait;
  end process;
end behaviour;

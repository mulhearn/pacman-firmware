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

  component digital_core
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

  -- analog front-end is not simulated:
  signal dout : std_logic_vector(639 downto 0) := (others => '0');
  signal done : std_logic_vector(63 downto 0)  := (others => '0');
  signal hit  : std_logic_vector(63 downto 0)  := (others => '0');

begin

  u_digital_core : digital_core
    port map (
      -- Clock, reset, trigger
      clk              => UCLK_I,
      reset_n          => G_I(0),
      external_trigger => H_I(0),

      -- UART interface (the four hydra-network ports)
      posi             => POSI_I(3 downto 0),
      piso             => PISO_O(3 downto 0),
      tx_enable        => open,

      -- Analog front-end inputs: tied off (no analog in emulation)
      dout             => dout,
      done             => done,
      hit              => hit,

      -- Per-channel digital outputs: unused in v1
      digital_monitor  => open,
      sample           => open,

      -- Analog configuration outputs: not consumed in FPGA emulation
      pixel_trim_dac          => open,
      threshold_global        => open,
      gated_reset             => open,
      csa_reset               => open,
      bypass_caps_enable      => open,
      ibias_tdac              => open,
      ibias_comp              => open,
      ibias_buffer            => open,
      ibias_csa               => open,
      ibias_vref_buffer       => open,
      ibias_vcm_buffer        => open,
      ibias_tpulse            => open,
      adc_ibias_delay         => open,
      ref_current_trim        => open,
      adc_comp_trim           => open,
      vref_dac                => open,
      vcm_dac                 => open,
      csa_bypass_enable       => open,
      csa_bypass_select       => open,
      csa_monitor_select      => open,
      csa_testpulse_enable    => open,
      csa_testpulse_dac       => open,
      adc_ibias_delay_monitor => open,
      current_monitor_bank0   => open,
      current_monitor_bank1   => open,
      current_monitor_bank2   => open,
      current_monitor_bank3   => open,
      voltage_monitor_bank0   => open,
      voltage_monitor_bank1   => open,
      voltage_monitor_bank2   => open,
      voltage_monitor_bank3   => open,
      voltage_monitor_refgen  => open,
      en_analog_monitor       => open,

      -- LVDS PHY configuration outputs: not used in emulation
      tx_slices0       => open,
      tx_slices1       => open,
      tx_slices2       => open,
      tx_slices3       => open,
      i_tx_diff0       => open,
      i_tx_diff1       => open,
      i_tx_diff2       => open,
      i_tx_diff3       => open,
      i_rx0            => open,
      i_rx1            => open,
      i_rx2            => open,
      i_rx3            => open,
      i_rx_clk         => open,
      i_rx_rst         => open,
      i_rx_ext_trig    => open,
      r_term0          => open,
      r_term1          => open,
      r_term2          => open,
      r_term3          => open,
      r_term_clk       => open,
      r_term_rst       => open,
      r_term_ext_trig  => open,
      v_cm_lvds_tx0    => open,
      v_cm_lvds_tx1    => open,
      v_cm_lvds_tx2    => open,
      v_cm_lvds_tx3    => open

    );

end behaviour;

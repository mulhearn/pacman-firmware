library ieee;
use ieee.std_logic_1164.all;

-- digital_core (loopback dummy)
--
-- Behavioral stub that mimics the LArPix v3c digital_core's interface
-- for use under GHDL where the proprietary SystemVerilog RTL is not
-- available. This stub does not implement the ASIC's protocol; it
-- simply loops the four POSI (RX) inputs back to the four PISO (TX)
-- outputs, allowing connectivity through asic_emu_unit and the
-- surrounding PACMAN logic to be exercised in simulation.
--
-- All analog configuration outputs are driven to zero. All other
-- digital outputs are likewise driven to safe constants.
--
-- This is *not* a faithful behavioral model of the ASIC; it is a
-- wiring test target. The real digital_core comes from
-- src/external/larpix_v3c/src/digital_core.sv at synthesis time.
--
entity digital_core is
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
end digital_core;

architecture loopback of digital_core is
begin

  -- The actual behavior: loop received bits straight back out
  piso             <= posi;

  -- Constant tie-offs for everything else
  digital_monitor         <= '0';
  sample                  <= (others => '0');
  tx_enable               <= (others => '1');
  pixel_trim_dac          <= (others => '0');
  threshold_global        <= (others => '0');
  gated_reset             <= (others => '0');
  csa_reset               <= (others => '0');
  bypass_caps_enable      <= (others => '0');
  ibias_tdac              <= (others => '0');
  ibias_comp              <= (others => '0');
  ibias_buffer            <= (others => '0');
  ibias_csa               <= (others => '0');
  ibias_vref_buffer       <= (others => '0');
  ibias_vcm_buffer        <= (others => '0');
  ibias_tpulse            <= (others => '0');
  adc_ibias_delay         <= (others => '0');
  ref_current_trim        <= (others => '0');
  adc_comp_trim           <= (others => '0');
  vref_dac                <= (others => '0');
  vcm_dac                 <= (others => '0');
  csa_bypass_enable       <= (others => '0');
  csa_bypass_select       <= (others => '0');
  csa_monitor_select      <= (others => '0');
  csa_testpulse_enable    <= (others => '0');
  csa_testpulse_dac       <= (others => '0');
  adc_ibias_delay_monitor <= (others => '0');
  current_monitor_bank0   <= (others => '0');
  current_monitor_bank1   <= (others => '0');
  current_monitor_bank2   <= (others => '0');
  current_monitor_bank3   <= (others => '0');
  voltage_monitor_bank0   <= (others => '0');
  voltage_monitor_bank1   <= (others => '0');
  voltage_monitor_bank2   <= (others => '0');
  voltage_monitor_bank3   <= (others => '0');
  voltage_monitor_refgen  <= (others => '0');
  en_analog_monitor       <= '0';
  tx_slices0              <= (others => '0');
  tx_slices1              <= (others => '0');
  tx_slices2              <= (others => '0');
  tx_slices3              <= (others => '0');
  i_tx_diff0              <= (others => '0');
  i_tx_diff1              <= (others => '0');
  i_tx_diff2              <= (others => '0');
  i_tx_diff3              <= (others => '0');
  i_rx0                   <= (others => '0');
  i_rx1                   <= (others => '0');
  i_rx2                   <= (others => '0');
  i_rx3                   <= (others => '0');
  i_rx_clk                <= (others => '0');
  i_rx_rst                <= (others => '0');
  i_rx_ext_trig           <= (others => '0');
  r_term0                 <= (others => '0');
  r_term1                 <= (others => '0');
  r_term2                 <= (others => '0');
  r_term3                 <= (others => '0');
  r_term_clk              <= (others => '0');
  r_term_rst              <= (others => '0');
  r_term_ext_trig         <= (others => '0');
  v_cm_lvds_tx0           <= (others => '0');
  v_cm_lvds_tx1           <= (others => '0');
  v_cm_lvds_tx2           <= (others => '0');
  v_cm_lvds_tx3           <= (others => '0');

end loopback;

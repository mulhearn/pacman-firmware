library ieee;
use ieee.std_logic_1164.all;

entity digital_core_wrapper is
    port (
        -- Clock and reset
        clk                     : in  std_logic;
        reset_n                 : in  std_logic;

        -- UART interfaces (the four hydra-network ports)
        posi                    : in  std_logic_vector(3 downto 0);
        piso                    : out std_logic_vector(3 downto 0);
        tx_enable               : out std_logic_vector(3 downto 0);

        -- External trigger
        external_trigger        : in  std_logic;

        -- Per-channel inputs from analog front-end
        dout                    : in  std_logic_vector(640-1 downto 0);  -- ADCBITS*NUMCHANNELS = 10*64
        done                    : in  std_logic_vector(63 downto 0);
        hit                     : in  std_logic_vector(63 downto 0);

        -- Digital monitor / per-channel sample
        digital_monitor         : out std_logic;
        sample                  : out std_logic_vector(63 downto 0);

        -- Analog core configuration outputs
        pixel_trim_dac          : out std_logic_vector(320-1 downto 0); -- PIXEL_TRIM_DAC_BITS*NUMCHANNELS = 5*64
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

        -- TX/RX bias and termination configuration (per-link)
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
        v_cm_lvds_tx3           : out std_logic_vector(3 downto 0)
    );
end entity digital_core_wrapper;

architecture rtl of digital_core_wrapper is

    component digital_core
        port (
            piso                    : out std_logic_vector(3 downto 0);
            digital_monitor         : out std_logic;
            sample                  : out std_logic_vector(63 downto 0);
            tx_enable               : out std_logic_vector(3 downto 0);
            pixel_trim_dac          : out std_logic_vector(320-1 downto 0);
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
            dout                    : in  std_logic_vector(640-1 downto 0);
            done                    : in  std_logic_vector(63 downto 0);
            hit                     : in  std_logic_vector(63 downto 0);
            external_trigger        : in  std_logic;
            posi                    : in  std_logic_vector(3 downto 0);
            clk                     : in  std_logic;
            reset_n                 : in  std_logic
        );
    end component;

begin

    u_digital_core : digital_core
        port map (
            piso                    => piso,
            digital_monitor         => digital_monitor,
            sample                  => sample,
            tx_enable               => tx_enable,
            pixel_trim_dac          => pixel_trim_dac,
            threshold_global        => threshold_global,
            gated_reset             => gated_reset,
            csa_reset               => csa_reset,
            bypass_caps_enable      => bypass_caps_enable,
            ibias_tdac              => ibias_tdac,
            ibias_comp              => ibias_comp,
            ibias_buffer            => ibias_buffer,
            ibias_csa               => ibias_csa,
            ibias_vref_buffer       => ibias_vref_buffer,
            ibias_vcm_buffer        => ibias_vcm_buffer,
            ibias_tpulse            => ibias_tpulse,
            adc_ibias_delay         => adc_ibias_delay,
            ref_current_trim        => ref_current_trim,
            adc_comp_trim           => adc_comp_trim,
            vref_dac                => vref_dac,
            vcm_dac                 => vcm_dac,
            csa_bypass_enable       => csa_bypass_enable,
            csa_bypass_select       => csa_bypass_select,
            csa_monitor_select      => csa_monitor_select,
            csa_testpulse_enable    => csa_testpulse_enable,
            csa_testpulse_dac       => csa_testpulse_dac,
            adc_ibias_delay_monitor => adc_ibias_delay_monitor,
            current_monitor_bank0   => current_monitor_bank0,
            current_monitor_bank1   => current_monitor_bank1,
            current_monitor_bank2   => current_monitor_bank2,
            current_monitor_bank3   => current_monitor_bank3,
            voltage_monitor_bank0   => voltage_monitor_bank0,
            voltage_monitor_bank1   => voltage_monitor_bank1,
            voltage_monitor_bank2   => voltage_monitor_bank2,
            voltage_monitor_bank3   => voltage_monitor_bank3,
            voltage_monitor_refgen  => voltage_monitor_refgen,
            en_analog_monitor       => en_analog_monitor,
            tx_slices0              => tx_slices0,
            tx_slices1              => tx_slices1,
            tx_slices2              => tx_slices2,
            tx_slices3              => tx_slices3,
            i_tx_diff0              => i_tx_diff0,
            i_tx_diff1              => i_tx_diff1,
            i_tx_diff2              => i_tx_diff2,
            i_tx_diff3              => i_tx_diff3,
            i_rx0                   => i_rx0,
            i_rx1                   => i_rx1,
            i_rx2                   => i_rx2,
            i_rx3                   => i_rx3,
            i_rx_clk                => i_rx_clk,
            i_rx_rst                => i_rx_rst,
            i_rx_ext_trig           => i_rx_ext_trig,
            r_term0                 => r_term0,
            r_term1                 => r_term1,
            r_term2                 => r_term2,
            r_term3                 => r_term3,
            r_term_clk              => r_term_clk,
            r_term_rst              => r_term_rst,
            r_term_ext_trig         => r_term_ext_trig,
            v_cm_lvds_tx0           => v_cm_lvds_tx0,
            v_cm_lvds_tx1           => v_cm_lvds_tx1,
            v_cm_lvds_tx2           => v_cm_lvds_tx2,
            v_cm_lvds_tx3           => v_cm_lvds_tx3,
            dout                    => dout,
            done                    => done,
            hit                     => hit,
            external_trigger        => external_trigger,
            posi                    => posi,
            clk                     => clk,
            reset_n                 => reset_n
        );

end architecture rtl;

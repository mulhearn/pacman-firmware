# Try to synthesize each LBNL module standalone, write results and first error line to file.

set modules {
    reset_sync
    async2sync
    gate_negedge_clk
    gate_posedge_clk
    fifo_latch
    sar_adc_cdc
    priority_fifo_arbiter
    periodic_pulser
    uart_tx
    uart_rx
    uart
    timestamp_gen
    digital_monitor
    config_regfile
    channel_ctrl
    comms_ctrl
    hydra_ctrl
    event_router
    external_interface
    digital_core
}

set results_file [open "elab_results.txt" w]

foreach mod $modules {
    puts "----- Trying: $mod -----"
    if {[catch {synth_design -rtl -name rtl_$mod -top $mod} err]} {
        # Find the first ERROR line in the captured output
        set first_err ""
        foreach line [split $err "\n"] {
            if {[regexp {ERROR:} $line]} {
                set first_err [string trim $line]
                break
            }
        }
        if {$first_err eq ""} {
            # Fall back to the first non-empty line
            foreach line [split $err "\n"] {
                set t [string trim $line]
                if {$t ne ""} { set first_err $t; break }
            }
        }
        puts "FAIL: $mod -- $first_err"
        puts $results_file [format "FAIL  %-25s %s" $mod $first_err]
    } else {
        puts "PASS: $mod"
        puts $results_file [format "PASS  %-25s" $mod]
    }
    flush $results_file
    catch {close_design}
}

close $results_file
puts "Results written to elab_results.txt"

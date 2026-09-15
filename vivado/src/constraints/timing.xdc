# timing.xdc -- CDC exceptions

# async first stage only
set_false_path -to [get_pins zsys_i/regbus_hub_0/U0/u_regbus_cdc/rd_req_sync_p_reg[0]/D]
set_false_path -to [get_pins zsys_i/regbus_hub_0/U0/u_regbus_cdc/rd_ack_sync_s_reg[0]/D]
set_false_path -to [get_pins zsys_i/regbus_hub_0/U0/u_regbus_cdc/wr_req_sync_p_reg[0]/D]
set_false_path -to [get_pins zsys_i/regbus_hub_0/U0/u_regbus_cdc/wr_ack_sync_s_reg[0]/D]

# RDATA, handshake-protected
set_max_delay -datapath_only 20 \
  -from [get_cells {zsys_i/rx_unit_0/U0/reg0/S_REGBUS_RB_RDATA_reg[*] \
                     zsys_i/tx_unit_0/U0/reg0/S_REGBUS_RB_RDATA_reg[*] \
                     zsys_i/atc_unit_0/U0/atcreg0/rdata_reg[*]}] \
  -to   [get_cells zsys_i/axil_to_regbus_0/U0/rdata_reg[*]]

# RADDR/WADDR/WDATA, handshake-protected
set_max_delay -datapath_only 20 \
  -from [get_cells {zsys_i/regbus_hub_0/U0/s_raddr_reg_reg[*] \
                     zsys_i/regbus_hub_0/U0/s_waddr_reg_reg[*] \
                     zsys_i/regbus_hub_0/U0/s_wdata_reg_reg[*]}] \
  -to   [get_cells {zsys_i/regbus_hub_0/U0/p_raddr_reg_reg[*] \
                     zsys_i/regbus_hub_0/U0/p_waddr_reg_reg[*] \
                     zsys_i/regbus_hub_0/U0/p_wdata_reg_reg[*]}]

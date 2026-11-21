from wave import bit, bus, plot

V = "atc_diagram_tb.vcd"
T = "atc_diagram_tb."
U = T + "uut."

# the strobes, the ASIC clock and the timestamp after reset (default periods:  10 clocks)
plot("atc_timer.pdf", V, [
    bit(T + "clk", "clk"),
    bit(T + "rst", "reset"),
    bit(U + "uart", "UART strobe"),
    bit(T + "baud", "BAUD strobe"),
    bit(T + "uclk", "UCLK"),
    bus(T + "ts16[15:0]", "timestamp", fmt=lambda v: "%d" % v),
], 0, 450)

# POKE C:  routed to H on tile 1 (destination tiles 0-3, poke mask 1), 25 clocks, aligned to the
# UART strobe + 3;  marker 0 (SYNC) restarts the timestamp
plot("atc_poke.pdf", V, [
    bit(T + "clk", "clk"),
    bit(U + "uart", "UART strobe"),
    bit(T + "wupdate", "REGBUS write"),
    bit(U + "poke_c", "POKE C"),
    bit(T + "h[9:0]", "H output 0", bits=(0, 0)),
    bit(T + "h[9:0]", "H output 1", bits=(1, 1)),
    bit(T + "marker[3:0]", "marker 0", bits=(0, 0)),
    bus(T + "ts16[15:0]", "timestamp", fmt=lambda v: "%d" % v),
], 740, 1260)

# LEMO A:  synchronized, edge detected, routed to G on all tiles for 10 clocks, aligned to the UART strobe
plot("atc_lemo.pdf", V, [
    bit(T + "clk", "clk"),
    bit(U + "uart", "UART strobe"),
    bit(T + "lemo_a", "LEMO A input"),
    bit(U + "lemo_sync[1:0]", "synchronized", bits=(0, 0)),
    bit(U + "lemo_a", "LEMO A pulse"),
    bit(T + "g[9:0]", "G output 0", bits=(0, 0)),
], 1480, 2080)

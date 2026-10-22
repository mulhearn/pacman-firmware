from wave import bit, bus, plot

V = "atc_diagram_tb.vcd"
T = "atc_diagram_tb."
U = T + "uut."
tiles = lambda v: format(v, "010b")

# the strobes, the ASIC clock and the timestamp after reset (default periods:  10 clocks)
plot("atc_timer.pdf", V, [
    bit(T + "clk", "clk"),
    bit(U + "uart", "UART strobe"),
    bit(T + "baud", "BAUD strobe"),
    bit(T + "uclk", "UCLK"),
    bus(T + "ts16[15:0]", "timestamp", fmt=lambda v: "%d" % v),
], 0, 450)

# POKE C:  routed to H on tiles 0 and 1 (destination tiles 0-3, poke mask 0-1), 25 clocks, aligned to the
# UART strobe + 3;  marker 0 (SYNC) restarts the timestamp
plot("atc_poke.pdf", V, [
    bit(T + "clk", "clk"),
    bit(U + "uart", "UART strobe"),
    bit(T + "wupdate", "REGBUS write"),
    bit(U + "poke_c", "POKE C"),
    bus(U + "h[9:0]", "H (internal)", fmt=tiles),
    bus(T + "h[9:0]", "H output", fmt=tiles),
    bit(T + "marker[3:0]", "marker 0", bits=(0, 0)),
    bus(T + "ts16[15:0]", "timestamp", fmt=lambda v: "%d" % v),
], 760, 1200)

# LEMO A:  synchronized, edge detected, routed to G on all tiles for 12 clocks, aligned to the UART strobe
plot("atc_lemo.pdf", V, [
    bit(T + "clk", "clk"),
    bit(U + "uart", "UART strobe"),
    bit(T + "lemo_a", "LEMO A input"),
    bit(U + "lemoa0.signal_sync", "synchronized"),
    bit(U + "lemo_a", "LEMO A pulse"),
    bit(U + "g[9:0]", "G (internal) 0", bits=(0, 0)),
    bit(T + "g[9:0]", "G output 0", bits=(0, 0)),
], 1480, 2080)

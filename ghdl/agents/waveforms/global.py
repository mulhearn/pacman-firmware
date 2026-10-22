from wave import bit, bus, plot

V = "global_diagram_tb.vcd"
T = "global_diagram_tb."
nz = lambda v: v != 0

# two writes (ENABLES, LEDS) and two reads (ENABLES, STATUS);  each answered one clock after the request
plot("global.pdf", V, [
    bit(T + "clk", "clk"),
    bit(T + "wupdate", "wupdate"),
    bus(T + "waddr[15:0]", "waddr", fmt=lambda v: "%04X" % v, show=nz),
    bus(T + "wdata[31:0]", "wdata", fmt=lambda v: "%08X" % v, show=nz),
    bit(T + "wack", "wack"),
    bit(T + "power", "TILE_POWER_EN"),
    bus(T + "tiles[9:0]", "TILE_EN", fmt=lambda v: "%03X" % v),
    bus(T + "leds[1:0]", "LED", fmt=lambda v: format(v, "02b")),
    bit(T + "rupdate", "rupdate"),
    bus(T + "raddr[15:0]", "raddr", fmt=lambda v: "%04X" % v, show=nz),
    bus(T + "rdata[31:0]", "rdata", fmt=lambda v: "%08X" % v, show=nz),
    bit(T + "rack", "rack"),
], 40, 150)

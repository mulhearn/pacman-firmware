from wave import bit, bus, strobe, plot

V = "rx_chan_diagram_tb.vcd"
T = "rx_chan_diagram_tb."
STATE = ["IDLE", "FIRST", "DATA", "STOP"]

# the start bit:  synchronizer, edge detection, the sample point PHASE clocks after the falling edge
plot("rx_chan_start.pdf", V, [
    bit(T + "clk", "clk"),
    bit(T + "baud", "BAUD"),
    bit(T + "rx", "RX input"),
    bit(T + "uut.rx_sync", "synchronized"),
    bit(T + "uut.rx_vote", "vote"),
    bit(T + "uut.rx_fall", "falling edge"),
    bus(T + "uut.rx_phase[7:0]", "edge phase", fmt=lambda v: "%d" % v, show=lambda v: v != 255),
    bit(T + "sample_en", "sample"),
    bus(T + "state[1:0]", "state", fmt=lambda v: STATE[v]),
    bit(T + "start", "start"),
], 1000, 1400)

# three frames:  the first is taken (READY), the second waits, the third is lost
plot("rx_chan_frames.pdf", V, [
    bit(T + "rx", "RX input"),
    bit(T + "update", "update"),
    bus(T + "data[63:0]", "data", fmt=lambda v: "%016X" % v, show=lambda v: v != 0, size=8),
    bit(T + "valid", "valid"),
    bit(T + "ready", "ready"),
    bit(T + "lost", "lost"),
], 800, 21500, unit="us")

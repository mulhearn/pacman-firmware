from wave import bit, bus, strobe, plot

V = "rx_chan_diagram_tb.vcd"
T = "rx_chan_diagram_tb."
STATE = ["IDLE", "START", "DATA", "STOP"]
ends = lambda v: "%04X\\ldots %04X" % (v >> 48, v & 0xFFFF)      # a 64-bit word by its first and last digits

# the start bit, three samples and their vote, the sample point PHASE clocks after the falling edge, with a
# one-clock glitch at the sample point of data bit 1
plot("rx_chan_noise.pdf", V, [
    bit(T + "clk", "clk"),
    bit(T + "baud", "baud"),
    bit(T + "rx", "POSI"),
    bit(T + "taps[2:0]", "tap(0)", bits=(0, 0)),
    bit(T + "taps[2:0]", "tap(1)", bits=(1, 1)),
    bit(T + "taps[2:0]", "tap(2)", bits=(2, 2)),
    bit(T + "vote", "vote"),
    bit(T + "dissent", "dissent"),
    bit(T + "uut.rx_fall", "falling edge"),
    bus(T + "uut.rx_phase[7:0]", "edge phase", fmt=lambda v: "%d" % v, show=lambda v: v != 255),
    bit(T + "sample_en", "sample"),
    bit(T + "noisy", "noisy"),
    bus(T + "state[1:0]", "state", fmt=lambda v: STATE[v]),
    bit(T + "start", "start"),
], 1000, 1400, row_h=0.29)

# four frames:  the glitch in the first (noisy), which is taken (ready);  the second has a low stop bit (frame
# error);  the third waits, since the RX buffer does not take it;  the fourth is lost
plot("rx_chan_frames.pdf", V, [
    bit(T + "rx", "POSI"),
    bit(T + "start", "start"),
    bit(T + "update", "update"),
    bit(T + "valid", "valid"),
    bit(T + "ready", "ready"),
    bus(T + "data[63:0]", "data", fmt=ends, show=lambda v: v != 0),
    bit(T + "noisy", "noisy"),
    bit(T + "frame_err", "frame error"),
    bit(T + "lost", "lost"),
], 800, 28300, unit="us")

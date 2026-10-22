from wave import bit, bus, plot

V = "tx_diagram_tb.vcd"
T = "tx_diagram_tb."
U = T + "uut."


def beat(v):
    if v >> 16 == 0:
        return "M"
    return "%d" % (v & 0xFF)


def first_last(v):
    return v != 0 and (v >> 16 == 0 or (v & 0xFF) in (0, 1, 2, 39))


# the two DMA packets into the TX buffer, and the hand-over to the UART channels
plot("tx_stream.pdf", V, [
    bit(T + "clk", "clk"),
    bit(T + "tvalid", "tvalid"),
    bit(T + "tready", "tready"),
    bit(T + "tlast", "tlast"),
    bus(T + "tdata[63:0]", "tdata", fmt=beat, show=first_last, size=7),
    bit(U + "valid[39:0]", "uvalid(0)", bits=(0, 0)),
    bit(U + "ready[39:0]", "uready(0)", bits=(0, 0)),
    bit(U + "valid[39:0]", "uvalid(1)", bits=(1, 1)),
    bit(U + "ready[39:0]", "uready(1)", bits=(1, 1)),
    bit(U + "valid[39:0]", "uvalid(2)", bits=(2, 2)),
    bit(U + "ready[39:0]", "uready(2)", bits=(2, 2)),
], 60, 1100)

# the UART frames:  packet 1 on UARTs 0-2, then packet 2 on UARTs 0 and 1, after the 2-bit delay
plot("tx_frames.pdf", V, [
    bit(U + "valid[39:0]", "uvalid(0)", bits=(0, 0)),
    bit(U + "ready[39:0]", "uready(0)", bits=(0, 0)),
    bit(T + "uut.posi_o[39:0]", "POSI(0)", bits=(0, 0)),
    bit(T + "uut.posi_o[39:0]", "POSI(1)", bits=(1, 1)),
    bit(U + "valid[39:0]", "uvalid(2)", bits=(2, 2)),
    bit(T + "uut.posi_o[39:0]", "POSI(2)", bits=(2, 2)),
], 0, 15000, unit="us")

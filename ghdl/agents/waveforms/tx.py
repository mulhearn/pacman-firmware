from wave import bit, bus, plot

V = "tx_diagram_tb.vcd"
T = "tx_diagram_tb."
U = T + "uut."

# packet 1 into the TX buffer, the hand-over to UART 1, and its start bit (word 0x...0101:  bit 0 is 1)
plot("tx_stream.pdf", V, [
    bit(T + "clk", "clk"),
    bus(T + "tdata[63:0]", "tdata", show=lambda v: False),
    bit(T + "tlast", "tlast"),
    bit(T + "tvalid", "tvalid"),
    bit(T + "tready", "tready"),
    bit(U + "valid[39:0]", "uvalid(1)", bits=(1, 1)),
    bit(U + "ready[39:0]", "uready(1)", bits=(1, 1)),
    bit(T + "uut.posi_o[39:0]", "POSI(1)", bits=(1, 1)),
    bit(T + "baud", "baud"),
], 60, 800, points=[(610, "POSI(1)", 0), (710, "POSI(1)", 0)])

# the UART frames:  packet 1 on UARTs 0-2, then packet 2 on UARTs 0 and 1, after the 2-bit delay
plot("tx_frames.pdf", V, [
    bit(U + "valid[39:0]", "uvalid(0)", bits=(0, 0)),
    bit(U + "ready[39:0]", "uready(0)", bits=(0, 0)),
    bit(T + "uut.posi_o[39:0]", "POSI(0)", bits=(0, 0)),
    bit(T + "uut.posi_o[39:0]", "POSI(1)", bits=(1, 1)),
    bit(U + "valid[39:0]", "uvalid(2)", bits=(2, 2)),
    bit(T + "uut.posi_o[39:0]", "POSI(2)", bits=(2, 2)),
], 0, 15000, unit="us")

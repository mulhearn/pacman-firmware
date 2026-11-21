from wave import bit, bus, plot

V = "rx_stream_diagram_tb.vcd"
T = "rx_stream_diagram_tb."
STATE = {0: "IDLE", 1: "WAIT", 2: "STREAM", 3: "TRAILER"}


def word(v):
    """the stream fragments of this testbench, by UART n:  header hn (its channel id is n+1), timestamp tn,
    data dn.  Trailer:  EOP header L (its word type), the count, 0"""
    if v & 0xFFFF == 0x0144:
        return "h%d" % ((v >> 16) - 1)
    if v & 0xFFFFF000 == 0x1000:
        return "t%d" % ((v - 0x1000) // 16)
    if v >> 8 == 0xDA7A00:
        return "d%d" % (v & 0xFF)
    if v == 0x4C:
        return "L"
    return "%d" % v


plot("rx_stream.pdf", V, [
    bit(T + "clk", "clk"),
    bit(T + "valid0", "uvalid(0)"),
    bit(T + "ready0", "uready(0)"),
    bit(T + "valid1", "uvalid(1)"),
    bit(T + "ready1", "uready(1)"),
    bit(T + "valid3", "uvalid(3)"),
    bit(T + "ready3", "uready(3)"),
    bus(T + "state[2:0]", "state", fmt=lambda v: STATE.get(v, "?")),
    bus(T + "turn[5:0]", "turn", fmt=lambda v: "%d" % v),
    bus(T + "frag[1:0]", "fragment", fmt=lambda v: "%d" % v),
    bit(T + "tvalid", "tvalid"),
    bus(T + "tdata[63:0]", "tdata", fmt=word, show=lambda v: v != 0),
    bit(T + "tlast", "tlast"),
], 90, 320)
